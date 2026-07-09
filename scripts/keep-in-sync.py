#!/usr/bin/env python3

import json
import os
import re
from configparser import ConfigParser
from dataclasses import astuple, dataclass
from pathlib import Path
from time import sleep
from typing import Dict, List, Optional, Set, Tuple, Self, Any
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import URLError

# before portage, we setup the overlay to here:
os.environ["PORTDIR_OVERLAY"] = str(Path(__file__).parent / "..")

import portage
from portage.exception import PortageKeyError, UnsupportedAPIException
from portage.package.ebuild import doebuild
from portage.dbapi.porttree import portdbapi


# constants:
OVERLAY_REGEX = re.compile(r"pkg_overlay(\s[\-\w\s]+)?")


class WorkingEnvironment:
    # these variables are static across multiple instances (aka shared):
    repo_name: str = "aptenodytes"
    default_repo_name: str = Path(portage.settings["PORTDIR"]).name
    repos_path: Path = Path(portage.settings["PORTDIR"]).parent
    portdbapi: portdbapi = portage.db[portage.settings["EROOT"]]["porttree"].dbapi
    accept_keywords: Set[str] = {"amd64", "arm64", "arm64-macos"}


class MyCatPkgVerRev(os.PathLike):  # Category/Package-Version-Rev
    cpv: str  # raw, vs my_cpv
    cat: str
    pkgname: str
    version: str
    rev: Optional[str]

    def __init__(
        self: Self, cpv: Optional[str] = None, path: Optional[Path] = None
    ) -> None:
        from portage.versions import catpkgsplit

        if path is not None:
            cpv = f"{path.parts[-3]}/{path.parts[-1].removesuffix('.ebuild')}"
        assert cpv is not None

        # different from catpkgsplit, we None the rev if not exist...
        cat, pkgname, version, rev = catpkgsplit(cpv)
        if rev == "r0" and not cpv.endswith("-r0"):
            rev = None

        self.cpv = cpv
        self.cat = cat
        self.pkgname = pkgname
        self.version = version
        self.rev = rev

    def __hash__(self: Self) -> int:
        return hash(self.cpv)

    def __eq__(self: Self, other: Any) -> bool:
        if type(other) is not MyCatPkgVerRev:
            return False
        return self.cpv == other.cpv

    def __repr__(self: Self) -> str:
        return self.cpv

    def __fspath__(self: Self) -> str:
        path = f"{self.cat}/{self.pkgname}/{self.pkgname}-{self.version}"
        if self.rev is not None:
            path += f"-{self.rev}"
        return path + ".ebuild"

    def is_meta_or_live(self: Self) -> bool:
        return self.version == "0" or "9999" in self.version

    # FIXME: -> List[Self]
    def cp_list(self: Self, env: WorkingEnvironment) -> List[Any]:
        return [
            MyCatPkgVerRev(cpv=cpv)
            for cpv in env.portdbapi.cp_list(f"{self.cat}/{self.pkgname}")
        ]

    def cmp(self: Self, other: Self) -> int:
        from portage.versions import pkgcmp, pkgsplit

        # TODO: simplify...
        return pkgcmp(pkgsplit(self.cpv), pkgsplit(other.cpv)) > 0

    # FIXME: -> Self
    def best(cpvs: List[Self]) -> Any:
        from portage.versions import best

        assert len(cpvs) > 0
        return MyCatPkgVerRev(cpv=best([my_cpv.cpv for my_cpv in cpvs]))


@dataclass
class EbuildPackage:
    my_cpv: MyCatPkgVerRev
    source: Optional[str]
    repo_name: str
    keywords: Set[str]


@dataclass
class OverlayPackage(EbuildPackage):
    repo_overlay: Optional[str]
    config: ConfigParser  # TODO: Remove


@dataclass
class ProfilePackage(EbuildPackage):
    config: ConfigParser  # TODO: Remove


def progress(text: str) -> None:
    columns = os.get_terminal_size().columns
    if len(text) > columns:
        text = text[:columns]
    padding = columns - len(text)
    print(text, " " * padding, sep="", end="\r")


def find_repo_path(env: WorkingEnvironment, repo_name: str) -> Path:
    if repo_name == env.repo_name:
        return Path(__file__).parent.parent.resolve()
    return env.repos_path / repo_name


def find_repology_cpv(my_cpv: MyCatPkgVerRev) -> Optional[MyCatPkgVerRev]:
    # deal with my special -p suffix...
    normalized = quote(my_cpv.pkgname.removesuffix("-p"))

    # land a rocket:
    url = f"https://repology.org/api/v1/project/{normalized}"
    req = Request(url, headers={"User-Agent": "github.com/plxty/aptenodytes"})
    try:
        with urlopen(req, timeout=5) as r:
            packages = json.load(r)
    except URLError as e:
        print(f"!!! Error fetching with {url}: {e}")
        return None

    # the repology is very strict for qps, only 1 request per second is allowed...
    sleep(1)

    # filter out newest:
    if not packages:
        return None
    package = next(filter(lambda package: package["status"] == "newest", packages))
    version: str = package["version"]

    # TODO: .clone()?
    assert not version.startswith("v")
    return MyCatPkgVerRev(cpv=f"{my_cpv.cat}/{my_cpv.pkgname}-{version}")


def find_best_cpv(
    env: WorkingEnvironment, package: EbuildPackage
) -> Tuple[str, MyCatPkgVerRev]:
    # sanity check, if we're special packages, there's no need to check best:
    if package.my_cpv.is_meta_or_live():
        return package.repo_name, package.my_cpv

    # respect package config, some may needs to be unstable:
    if type(package) is OverlayPackage or type(package) is ProfilePackage:
        pin_version_prefix = package.config.get(
            "aptenodytes", "pin_version_prefix", fallback=None
        )
        accept_keywords = set(
            package.config.get("aptenodytes", "accept_keywords", fallback="").split()
        )
        accept_keywords.update(env.accept_keywords)
    else:
        pin_version_prefix: Optional[str] = None
        accept_keywords = env.accept_keywords

    # filtering the cpvs, we pick only what we want, no live packages, etc.
    my_cpvs: Dict[MyCatPkgVerRev, str] = dict()
    for my_cpv in package.my_cpv.cp_list(env):
        if my_cpv.is_meta_or_live():
            continue

        # we only need whose prefix matching, aka. version range:
        if pin_version_prefix is not None:
            if not my_cpv.version.startswith(pin_version_prefix):
                continue

        try:
            keywords = set(env.portdbapi.aux_get(my_cpv.cpv, ["KEYWORDS"])[0].split())
        except PortageKeyError:
            continue
        if len(keywords.intersection(accept_keywords)) == 0:
            continue
        my_cpvs[my_cpv] = cpv_find_repo(env, my_cpv, True)

    # for non-overlay, we also add a repology version:
    if type(package) is OverlayPackage and package.repo_overlay is None:
        repology_cpv = find_repology_cpv(package.my_cpv)
        if repology_cpv is not None:
            my_cpvs[repology_cpv] = "repology"

    # falling back...
    if len(my_cpvs) == 0:
        my_cpvs[package.my_cpv] = package.repo_name

    # best!
    my_cpv = MyCatPkgVerRev.best(list(my_cpvs.keys()))
    return my_cpvs[my_cpv], my_cpv


def cpv_find_repo(
    env: WorkingEnvironment, my_cpv: MyCatPkgVerRev, exact_v: bool
) -> str:
    # find exactly match first:
    ebuild, overlay = env.portdbapi.findname2(my_cpv.cpv)
    if ebuild is not None:
        return overlay.rsplit("/", maxsplit=1)[-1]
    if exact_v:
        return env.default_repo_name

    # if there's any error, we pick any of one in the list... TODO: strategy?
    my_cpvs = my_cpv.cp_list(env)
    if len(my_cpvs) == 0:
        return env.default_repo_name
    return cpv_find_repo(env, my_cpvs[0], True)


def parse_comment_config(text: str) -> Optional[ConfigParser]:
    if not text.startswith("# [aptenodytes]"):
        return None

    # space as return, comma as space:
    config_text = text.replace(" ", "\n").replace(",", " ")

    # then we're:
    config = ConfigParser()
    config.read_string(config_text)
    return config


def collect_ebuild_package(
    env: WorkingEnvironment, repo_name: str, my_cpv: MyCatPkgVerRev
) -> EbuildPackage:
    # fetching things from ebuild, TODO: any other helpers?
    ebuild = str(find_repo_path(env, repo_name) / my_cpv)
    try:
        settings = portage.config(clone=portage.settings)
        settings.setcpv(my_cpv.cpv, mydb=env.portdbapi)
        doebuild.doebuild_environment(
            ebuild, "depend", settings=settings, db=env.portdbapi
        )
        keywords = set(settings["KEYWORDS"].split())
    except (PortageKeyError, UnsupportedAPIException):
        keywords = env.accept_keywords

    # verbosity package...
    return EbuildPackage(my_cpv, ebuild, repo_name, keywords)


def parse_pkg_overlay(text: str, default: str) -> Optional[str]:
    match = OVERLAY_REGEX.search(text)
    if match is None:
        return None

    # mostly useless now, as we query all the cpv_list regardless which repo:
    args = match[0].split()
    for i, arg in enumerate(args):
        if arg == "--repo":
            return args[i + 1]
    return default


def collect_overlay_package(
    env: WorkingEnvironment, my_cpv: MyCatPkgVerRev
) -> OverlayPackage:
    ebuild_package = collect_ebuild_package(env, env.repo_name, my_cpv)
    ebuild = ebuild_package.source
    assert ebuild is not None

    # deducing the comment config and actual overlay:
    config: Optional[ConfigParser] = None
    repo_overlay: Optional[str] = None
    with open(ebuild, "r") as reader:
        lines = reader.readlines()
    for line in lines:
        if config is None:
            config = parse_comment_config(line)
            if config is not None:
                continue

        if repo_overlay is None:
            repo_overlay = parse_pkg_overlay(line, env.default_repo_name)

    # hey i'm over laying:
    if config is None:
        config = ConfigParser()
    return OverlayPackage(*astuple(ebuild_package), repo_overlay, config)


def collect_profile_packages(
    env: WorkingEnvironment, fullpath: Path
) -> List[ProfilePackage]:
    # reading the whole profile package list:
    packages: List[ProfilePackage] = list()
    with open(fullpath, "r") as reader:
        lines = reader.readlines()

    # parsing the list into ebuild packages:
    config: ConfigParser = ConfigParser()
    for line in lines:
        # config can be reused until next block, to allow bulk:
        config_next = parse_comment_config(line)
        if config_next is not None:
            config = config_next
            continue

        cpv = line.removeprefix("=")
        if cpv == line:
            continue
        cpv = cpv.split(maxsplit=1)[0]
        my_cpv = MyCatPkgVerRev(cpv=cpv)

        # it may not exists in the repo, so we need searching:
        repo_name = cpv_find_repo(env, my_cpv, False)
        ebuild_package = collect_ebuild_package(env, repo_name, my_cpv)
        profile_package = ProfilePackage(*astuple(ebuild_package), config)
        packages.append(profile_package)

    return packages


def main() -> None:
    # prepare things up:
    env = WorkingEnvironment()
    overlay_packages: List[OverlayPackage] = list()
    profile_packages: List[ProfilePackage] = list()

    # obtain every normal packages, filter only really overlays:
    repo_path = find_repo_path(env, env.repo_name)
    for ebuild_path in repo_path.glob("**/*.ebuild", recurse_symlinks=True):
        progress(f"ebuild: {ebuild_path}")
        my_cpv = MyCatPkgVerRev(path=ebuild_path)
        overlay_packages.append(collect_overlay_package(env, my_cpv))

    # obtain profiles packages, to show if they needs update:
    repo_profiles_path = repo_path / "profiles"
    for profile in ["package.accept_keywords"]:
        for profile_path in repo_profiles_path.glob(
            f"**/{profile}", recurse_symlinks=True
        ):
            for package in collect_profile_packages(env, profile_path):
                progress(f"profile: {profile_path}: {package.my_cpv}")
                profile_packages.append(package)

    # find the best cpv, check if any updates:
    for package in overlay_packages + profile_packages:
        progress(f"overlay: {package.my_cpv}")
        repo_name, my_cpv = find_best_cpv(env, package)
        if my_cpv == package.my_cpv:
            continue

        # we might go a little bit too far:
        pin_until_stable = package.config.getboolean(
            "aptenodytes", "pin_until_stable", fallback=False
        )
        if pin_until_stable and package.my_cpv.cmp(my_cpv) > 0:
            continue
        if type(package) is OverlayPackage:
            typ = "overlay"
        else:
            typ = "profile"
        print(
            f">>> {typ}: {package.my_cpv} ({package.repo_name}) -> {my_cpv} ({repo_name})"
        )


if __name__ == "__main__":
    main()

#!/usr/bin/env python3

import json
import os
import re
from configparser import ConfigParser
from dataclasses import astuple, dataclass
from pathlib import Path
from time import sleep
from typing import Dict, List, Optional, Set, Tuple
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import URLError

# before portage, we setup the overlay to here:
os.environ["PORTDIR_OVERLAY"] = str(Path(__file__).parent / "..")

import portage
from portage.exception import PortageKeyError, UnsupportedAPIException
from portage.package.ebuild import doebuild
from portage.versions import best, catpkgsplit, pkgcmp, pkgsplit
from portage.dbapi.porttree import portdbapi


# constants:
OVERLAY_REGEX = re.compile(r"pkg_overlay(\s[\-\w\s]+)?")


@dataclass
class EbuildPackage:
    cpv: str
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


class WorkingEnvironment:
    # these variables are static across multiple instances (aka shared):
    repo_name: str = "aptenodytes"
    default_repo_name: str = Path(portage.settings["PORTDIR"]).name
    repos_path: Path = Path(portage.settings["PORTDIR"]).parent
    portdbapi: portdbapi = portage.db[portage.settings["EROOT"]]["porttree"].dbapi
    accept_keywords: Set[str] = {"amd64", "arm64", "arm64-macos"}


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


def find_repology_cpv(category: str, name: str) -> Optional[str]:
    # deal with my special -p suffix...
    normalized = quote(name.removesuffix("-p"))

    # land a rocket:
    url = f"https://repology.org/api/v1/project/{normalized}"
    req = Request(url, headers={"User-Agent": "github.com/plxty/aptenodytes"})
    try:
        with urlopen(req) as r:
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

    assert not version.startswith("v")
    return f"{category}/{name}-{version}"


def cpv_is_meta_or_live(cpv: str) -> bool:
    _, _, ver, _ = catpkgsplit(cpv)
    return ver == "0" or "9999" in ver


def find_best_cpv(env: WorkingEnvironment, package: EbuildPackage) -> Tuple[str, str]:
    # sanity check, if we're special packages, there's no need to check best:
    if cpv_is_meta_or_live(package.cpv):
        return package.repo_name, package.cpv

    # list all cpvs from all available repos:
    category, name, *_ = catpkgsplit(package.cpv)
    candidate_cpvs: List[str] = env.portdbapi.cp_list(f"{category}/{name}")

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
    cpvs: Dict[str, str] = dict()
    for cpv in candidate_cpvs:
        if cpv_is_meta_or_live(cpv):
            continue

        # we only need whose prefix matching, aka. version range:
        if pin_version_prefix is not None:
            _, _, ver, _ = catpkgsplit(cpv)
            if not ver.startswith(pin_version_prefix):
                continue

        try:
            keywords = set(env.portdbapi.aux_get(cpv, ["KEYWORDS"])[0].split())
        except PortageKeyError:
            continue
        if len(keywords.intersection(accept_keywords)) == 0:
            continue
        cpvs[cpv] = cpv_find_repo(env, cpv, True)

    # for non-overlay, we also add a repology version:
    if type(package) is OverlayPackage and package.repo_overlay is None:
        repology_cpv = find_repology_cpv(category, name)
        if repology_cpv is not None:
            cpvs[repology_cpv] = "repology"

    # falling back...
    if len(cpvs) == 0:
        cpvs[package.cpv] = package.repo_name

    # best!
    cpv = best(list(cpvs.keys()))
    return cpvs[cpv], cpv


def cpv_find_repo(env: WorkingEnvironment, cpv: str, exact_v: bool) -> str:
    # find exactly match first:
    ebuild, overlay = env.portdbapi.findname2(cpv)
    if ebuild is not None:
        return overlay.rsplit("/", maxsplit=1)[-1]
    if exact_v:
        return env.default_repo_name

    # if there's any error, we pick any of one in the list... TODO: strategy?
    category, name, *_ = catpkgsplit(cpv)
    cpvs = env.portdbapi.cp_list(f"{category}/{name}")
    if len(cpvs) == 0:
        return env.default_repo_name
    return cpv_find_repo(env, cpvs[0], True)


def path_to_cpv(path: Path) -> str:
    return f"{path.parts[-3]}/{path.parts[-1].removesuffix('.ebuild')}"


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
    env: WorkingEnvironment, repo_name: str, cpv: str
) -> EbuildPackage:
    # fetching things from ebuild, TODO: any other helpers?
    category, name, *_ = catpkgsplit(cpv)
    pf = cpv.split("/", maxsplit=1)[-1]
    ebuild = str(find_repo_path(env, repo_name) / category / name / f"{pf}.ebuild")
    try:
        settings = portage.config(clone=portage.settings)
        settings.setcpv(cpv, mydb=env.portdbapi)
        doebuild.doebuild_environment(
            ebuild, "depend", settings=settings, db=env.portdbapi
        )
        keywords = set(settings["KEYWORDS"].split())
    except (PortageKeyError, UnsupportedAPIException):
        keywords = env.accept_keywords

    # verbosity package...
    return EbuildPackage(cpv, ebuild, repo_name, keywords)


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


def collect_overlay_package(env: WorkingEnvironment, cpv: str) -> OverlayPackage:
    ebuild_package = collect_ebuild_package(env, env.repo_name, cpv)
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

        # it may not exists in the repo, so we need searching:
        repo_name = cpv_find_repo(env, cpv, False)
        ebuild_package = collect_ebuild_package(env, repo_name, cpv)
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
        cpv = path_to_cpv(ebuild_path)
        overlay_packages.append(collect_overlay_package(env, cpv))

    # obtain profiles packages, to show if they needs update:
    repo_profiles_path = repo_path / "profiles"
    for profile in ["package.accept_keywords"]:
        for profile_path in repo_profiles_path.glob(
            f"**/{profile}", recurse_symlinks=True
        ):
            for package in collect_profile_packages(env, profile_path):
                progress(f"profile: {profile_path}: {package.cpv}")
                profile_packages.append(package)

    # find the best cpv, check if any updates:
    for package in overlay_packages + profile_packages:
        progress(f"overlay: {package.cpv}")
        repo_name, cpv = find_best_cpv(env, package)
        if cpv == package.cpv:
            continue

        # we might go a little bit too far:
        pin_until_stable = package.config.getboolean(
            "aptenodytes", "pin_until_stable", fallback=False
        )
        if pin_until_stable and pkgcmp(pkgsplit(package.cpv), pkgsplit(cpv)) > 0:
            continue
        if type(package) is OverlayPackage:
            typ = "overlay"
        else:
            typ = "profile"
        print(f">>> {typ}: {package.cpv} ({package.repo_name}) -> {cpv} ({repo_name})")


if __name__ == "__main__":
    main()

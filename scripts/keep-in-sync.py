#!/usr/bin/env python3

import json
import os
import sys
from grp import getgrgid
from configparser import ConfigParser
from dataclasses import astuple, dataclass
from pathlib import Path
from time import sleep
from typing import Dict, List, Optional, Set, Tuple, Self, Any
from subprocess import check_call, Popen, PIPE
from shutil import rmtree, copyfile, SameFileError
from urllib.parse import quote
from urllib.request import Request, urlopen
from urllib.error import URLError

# before portage, we setup the overlay to here:
os.environ["PORTDIR_OVERLAY"] = str(Path(__file__).parent / "..")

import portage
from portage.exception import PortageKeyError, UnsupportedAPIException
from portage.package.ebuild import doebuild
from portage.dbapi.porttree import portdbapi
from portage.package.ebuild.config import config as ebuild_config

# enforce sync mode to allow nonexistent directory:
portage._sync_mode = True


class WorkingEnvironment:
    # these variables are static across multiple instances (aka shared):
    repos_path: Path = Path(portage.settings["PORTDIR"]).parent
    repo_override: str = Path(portage.settings["PORTDIR"]).name
    portdbapi: portdbapi = portage.db[portage.settings["EROOT"]]["porttree"].dbapi
    accept_keywords: Set[str] = {"amd64", "arm64", "arm64-macos"}

    # private vars, mostly arguments:
    oneshot: Optional[str] = None
    skip_refresh: bool = False
    repology: bool = False
    pretend: bool = False

    def __init__(self: Self) -> None:
        argv = sys.argv[1:]
        i = 0
        while i < len(argv):
            match argv[i]:
                case "--oneshot":
                    self.oneshot = argv[i + 1]
                    i += 1
                case "--skip-refresh":
                    self.skip_refresh = True
                case "--repology":
                    self.repology = True
                case "--pretend":
                    self.pretend = True
            i += 1


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
    source: Optional[Path]
    repo_overlay: str
    keywords: Set[str]


@dataclass
class OverlayPackage(EbuildPackage):
    repo_override: Optional[str]
    config: ConfigParser  # TODO: Remove


@dataclass
class ProfilePackage(EbuildPackage):
    profile_path: Path
    config: ConfigParser  # TODO: Remove


def progress(text: str) -> None:
    columns = os.get_terminal_size().columns
    if len(text) > columns:
        text = text[:columns]
    padding = columns - len(text)
    print(text, " " * padding, sep="", end="\r")


def find_repo_path(env: WorkingEnvironment, repo_name: str) -> Path:
    if repo_name == "aptenodytes":
        return Path(__file__).parents[1].resolve()
    return env.repos_path / repo_name


def find_repology_cpv(my_cpv: MyCatPkgVerRev) -> Optional[MyCatPkgVerRev]:
    url = f"https://repology.org/api/v1/project/{quote(my_cpv.pkgname)}"
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
        return package.repo_overlay, package.my_cpv

    try:
        slot = env.portdbapi.aux_get(package.my_cpv.cpv, ["SLOT"])[0]
        if slot == "ridgeni":
            return package.repo_overlay, package.my_cpv
    except PortageKeyError:
        pass

    accept_keywords = env.accept_keywords.copy()
    if type(package) is OverlayPackage or type(package) is ProfilePackage:
        accept_keywords.update(
            package.config.get("aptenodytes", "accept_keywords", fallback="").split()
        )

    # overlay vs override...
    is_overlay = type(package) is OverlayPackage
    is_override = is_overlay and package.repo_override is not None

    my_cpvs: Dict[MyCatPkgVerRev, str] = dict()
    for my_cpv in package.my_cpv.cp_list(env):
        if my_cpv.is_meta_or_live():
            continue

        # selected myself, just let me go:
        if package.my_cpv == my_cpv:
            my_cpvs[my_cpv] = package.repo_overlay
            continue

        try:
            keywords = set(env.portdbapi.aux_get(my_cpv.cpv, ["KEYWORDS"])[0].split())
        except PortageKeyError:
            continue
        if len(keywords.intersection(accept_keywords)) == 0:
            continue

        # targetting to override, if latest, cpv_find_repo will returns repo_overlay:
        repo = cpv_find_repo(env, my_cpv, True)
        if (
            package.repo_overlay != repo
            and is_override
            and package.repo_override != repo
        ):
            continue

        my_cpvs[my_cpv] = repo

    # for non-override, we also add a repology version, TODO: --repology switch?
    if env.repology and is_overlay and not is_override:
        repology_cpv = find_repology_cpv(package.my_cpv)
        if repology_cpv is not None:
            my_cpvs[repology_cpv] = "repology"

    # falling back...
    if len(my_cpvs) == 0:
        my_cpvs[package.my_cpv] = package.repo_overlay

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
        return "aptenodytes"

    # if there's any error, we pick any of one in the list... TODO: strategy?
    my_cpvs = my_cpv.cp_list(env)
    if len(my_cpvs) == 0:
        return "aptenodytes"
    return cpv_find_repo(env, my_cpvs[0], True)


def parse_comment_config(
    text: str, config: Optional[ConfigParser]
) -> Optional[ConfigParser]:
    if not text.startswith("# [aptenodytes]"):
        return None

    # space as return, comma as space:
    config_text = text.replace(" ", "\n").replace(",", " ")

    # then we're, the read_string will not clear existences:
    if config is None:
        config = ConfigParser()
    config.read_string(config_text)
    return config


def collect_ebuild_package(
    env: WorkingEnvironment, repo_name: str, my_cpv: MyCatPkgVerRev
) -> EbuildPackage:
    # fetching things from ebuild, TODO: any other helpers?
    ebuild = find_repo_path(env, repo_name) / my_cpv
    try:
        settings = portage.config(clone=portage.settings)
        settings.setcpv(my_cpv.cpv, mydb=env.portdbapi)

        # setting to me, portage uses a user that cannot access pwd when sudo:
        # @see portage _get_global
        if all(map(lambda v: v in os.environ, ["SUDO_USER", "SUDO_GID"])):
            group = getgrgid(int(os.environ["SUDO_GID"])).gr_name
            settings["PORTAGE_GRPNAME"] = group
            settings["PORTAGE_USERNAME"] = os.environ["SUDO_USER"]

        doebuild.doebuild_environment(
            str(ebuild), "depend", settings=settings, db=env.portdbapi
        )
        keywords = set(settings["KEYWORDS"].split())
    except (PortageKeyError, UnsupportedAPIException):
        keywords = env.accept_keywords

    # verbosity package...
    return EbuildPackage(my_cpv, ebuild, repo_name, keywords)


def collect_overlay_package(
    env: WorkingEnvironment, my_cpv: MyCatPkgVerRev
) -> OverlayPackage:
    ebuild_package = collect_ebuild_package(env, "aptenodytes", my_cpv)
    ebuild = ebuild_package.source
    assert ebuild is not None

    # try if package.override, and make config:
    override = ebuild.parent / "package.override"
    repo_override: Optional[str] = None
    config = ConfigParser()
    if override.is_file():  # TODO: support directories...
        with open(override, "r") as reader:
            lines = reader.readlines()
        for line in lines:
            if (
                line.startswith("diff ")
                # consider config within the patch:
                or parse_comment_config(line, config) is not None
                or (
                    line.startswith("+")
                    and parse_comment_config(line[1:], config) is not None
                )
            ):
                continue
        repo_override = env.repo_override
    else:
        # only collect from ebuild if it's not a override, aka owned:
        with open(ebuild, "r") as reader:
            lines = reader.readlines()
        for line in lines:
            if parse_comment_config(line, config) is not None:
                continue

    # try if overrides:
    repo_override = config.get("aptenodytes", "repo_override", fallback=repo_override)

    # hey i'm over laying:
    return OverlayPackage(*astuple(ebuild_package), repo_override, config)


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
        if (next_config := parse_comment_config(line, None)) is not None:
            config = next_config
            continue

        cpv = line.removeprefix("=")
        if cpv == line:
            continue
        cpv = cpv.split(maxsplit=1)[0]
        my_cpv = MyCatPkgVerRev(cpv=cpv)

        # it may not exists in the repo, so we need searching:
        repo_name = cpv_find_repo(env, my_cpv, False)
        ebuild_package = collect_ebuild_package(env, repo_name, my_cpv)
        profile_package = ProfilePackage(*astuple(ebuild_package), fullpath, config)
        packages.append(profile_package)

    return packages


def sync_emerge() -> None:
    for repo in ebuild_config().repositories:
        if repo.sync_type is None:
            continue

        sync_type = "rsync"
        if os.path.exists(f"{repo.location}/.git/index"):
            sync_type = "git"

        if os.path.exists(repo.location) and sync_type != repo.sync_type:
            print(f">>> Resetting repository {repo.name}...")
            rmtree(repo.location)
        else:
            print(f">>> Refreshing repository {repo.name}...")

        # real the work:
        check_call(["emerge", "--sync", "--quiet", repo.name])


def sync_overlay_package(
    old_package: OverlayPackage, new_package: EbuildPackage, manifest: bool
) -> None:
    # no way to support repology now...
    if new_package.repo_overlay == "repology":
        print(f"!!! Repology unavailable for {old_package.my_cpv}")
        return

    src = new_package.source
    dst = old_package.source.parent / new_package.source.name
    try:
        copyfile(src, dst)
    except SameFileError:
        pass

    # the reason why it becomes complex, is gentoo forced sandbox in the depend
    # phase, causing all reads outside current overlay fails, so the only way
    # we can workaround (without patching portage) is to copy-then-patch, huh.
    # @see https://github.com/gentoo/portage/commit/4671dba39326c02d2e649b95f211e16aa46cd275
    override = dst.parent / "package.override"
    if override.is_file():
        with open(override, "r") as reader:
            lines = reader.readlines()

        # modify the patch file to pointing to latest file:
        a: Optional[str] = None  # to verify the diff format
        for i, line in enumerate(lines):
            if line.startswith("diff --git a/"):
                _, a, b = line.strip().rsplit(maxsplit=2)
                a, b = a[len("a/") :], b[len("b/") :]
                assert a == b
            elif line.startswith("index "):
                continue
            elif line.startswith("--- a/") or line.startswith("+++ b/"):
                _, b = line.strip().rsplit(maxsplit=1)
                b = b[len("x/") :]
                assert a == b
            else:
                a = None
                continue

            assert a is not None
            if a.endswith(".ebuild"):
                patch_src = new_package.source.relative_to(
                    new_package.source.parents[2]
                )
                lines[i] = line.replace(a, str(patch_src))
            elif a.endswith(".eclass"):
                # sync eclass if any, to handle in the patch as well:
                eclass_src = new_package.source.parents[2] / a
                eclass_dst = old_package.source.parents[2] / a
                copyfile(eclass_src, eclass_dst)
            else:
                raise

        # TODO: check_output with input=?
        patch_process = Popen(
            [
                "patch",
                "-p1",
                "-r",
                "/dev/null",
                "--no-backup-if-mismatch",
            ],
            text=True,
            cwd=Path(__file__).parents[1],
            stdin=PIPE,
        )
        for line in lines:
            patch_process.stdin.write(line)
        patch_process.stdin.close()
        if patch_process.wait() != 0:
            raise

        # patch is success, store back for furthur simple modification:
        with open(override, "w") as writer:
            for line in lines:
                writer.write(line)

        # sync filesdir as well, TODO: consider removing old files?
        files_src = src.parent / "files"
        if files_src.is_dir():
            files_dst = dst.parent / "files"
            os.makedirs(files_dst, exist_ok=True)
            check_call(["rsync", "-a", f"{files_src}/.", files_dst])

    # TODO: make-bundle.py
    if manifest:
        check_call(["ebuild", dst, "manifest"])

    # reseting permissions back:
    stat = old_package.source.stat()
    check_call(["chown", "-R", f"{stat.st_uid}:{stat.st_gid}", dst.parent])
    print(f"=== Syncd overlay: {new_package.my_cpv}::{new_package.repo_overlay}")


def sync_profile_package(
    old_package: ProfilePackage, new_package: EbuildPackage
) -> None:
    profile_path = old_package.profile_path
    with open(profile_path, "r") as reader:
        lines = reader.readlines()
    with open(profile_path, "w") as writer:
        for line in lines:
            if line.startswith("="):
                line = line.replace(str(old_package.my_cpv), str(new_package.my_cpv))
            writer.write(line)
    print(f"=== Syncd profile: {new_package.my_cpv}::{new_package.repo_overlay}")


def main() -> None:
    env = WorkingEnvironment()

    # sync rest of the world first:
    if not env.skip_refresh:
        sync_emerge()

    # oneshot for one overlay package:
    if env.oneshot is not None:
        my_cpv = MyCatPkgVerRev(cpv=env.oneshot)
        a = collect_overlay_package(env, my_cpv)
        b = collect_ebuild_package(env, a.repo_override, my_cpv)
        sync_overlay_package(a, b, False)
        return

    # obtain every normal packages, filter only really overlays:
    packages: List[EbuildPackage] = list()
    repo_path = find_repo_path(env, "aptenodytes")
    for ebuild_path in repo_path.glob("**/*.ebuild", recurse_symlinks=True):
        progress(f"overlay: {ebuild_path}")
        my_cpv = MyCatPkgVerRev(path=ebuild_path)
        packages.append(collect_overlay_package(env, my_cpv))

    # obtain profiles packages, to show if they needs update:
    for profile_path in (repo_path / "profiles").glob(
        "**/package.accept_keywords", recurse_symlinks=True
    ):
        for package in collect_profile_packages(env, profile_path):
            progress(f"profile: {profile_path}: {package.my_cpv}")
            packages.append(package)

    # find the best cpv, check if any updates:
    pendings: List[Tuple[EbuildPackage, EbuildPackage]] = list()
    for package in packages:
        progress(f"package: {package.my_cpv}")
        repo_name, my_cpv = find_best_cpv(env, package)

        # nothing changes:
        if my_cpv == package.my_cpv:
            continue

        # skip it to un-check:
        if package.config.getboolean("aptenodytes", "skip", fallback=False):
            continue

        # we might go a little bit too far:
        pin_until_stable = package.config.getboolean(
            "aptenodytes", "pin_until_stable", fallback=False
        )
        if pin_until_stable and package.my_cpv.cmp(my_cpv) > 0:
            continue

        pendings.append((package, collect_ebuild_package(env, repo_name, my_cpv)))

    # try to sync:
    progress("")
    for old_package, new_package in pendings:
        if env.pretend:
            if type(old_package) is OverlayPackage:
                typ = "overlay"
            elif type(old_package) is ProfilePackage:
                typ = "profile"
            else:
                raise
            print(
                f">>> {typ}:",
                old_package.my_cpv,
                f"({old_package.repo_overlay})",
                "->",
                new_package.my_cpv,
                f"({new_package.repo_overlay})",
            )
            continue

        if type(old_package) is OverlayPackage:
            sync_overlay_package(old_package, new_package, True)
        elif type(old_package) is ProfilePackage:
            sync_profile_package(old_package, new_package)
        else:
            raise


if __name__ == "__main__":
    main()

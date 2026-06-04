#!/usr/bin/env python3
from unittest.mock import DEFAULT

from dataclasses import dataclass, astuple
from pathlib import Path
from typing import List, Set, Dict, Optional, Tuple
from configparser import ConfigParser
import portage
from portage.package.ebuild import doebuild
from portage.versions import catpkgsplit, best, pkgsplit, pkgcmp
from portage.exception import UnsupportedAPIException, PortageKeyError
import os
import sys
import re

@dataclass
class Version:
    version: str
    revision: Optional[str]

    def full(self) -> str:
        return self.version if self.revision is None else f"{self.version}-{self.revision}"

    def __lt__(self, other) -> bool:
        return portage.versions.vercmp(self.full(), other.full()) < 0

@dataclass
class Package:
    name: str
    version: Version
    source: Optional[str]

@dataclass
class EbuildPackage(Package):
    repo_name: str
    cpv: str
    keywords: Set[str]

@dataclass
class OverlayPackage(EbuildPackage):
    repo_overlay: Optional[str]
    config: ConfigParser  # TODO: Remove

@dataclass
class ProfilePackage(EbuildPackage):
    config: ConfigParser  # TODO: Remove

@dataclass
class RepologyPackage(Package):
    pass

class WorkingEnvironment:
    repo_name: str = "aptenodytes"
    default_repo_name: str = Path(portage.settings["PORTDIR"]).name
    repos_path: Path = Path(portage.settings["PORTDIR"]).parent
    portdbapi: portage.dbapi.porttree.portdbapi = portage.db[portage.settings["EROOT"]]["porttree"].dbapi
    accept_keywords: Set[str] = {"amd64", "arm64", "arm64-macos", "~arm64-macos"}

def cpv_to_path(cpv: str) -> Path:
    # TODO: any other helpers?
    category, name, *_ = catpkgsplit(cpv)
    p: Path = Path(category) / name / (cpv.split("/", maxsplit=1)[1] + ".ebuild")
    return p.resolve()

def find_best_cpv(env: WorkingEnvironment, cpv: str, config: ConfigParser) -> Tuple[str, str]:
    # list all cpvs from all available repos:
    category, name, *_ = catpkgsplit(cpv)
    candidate_cpvs: List[str] = env.portdbapi.cp_list(f"{category}/{name}")

    # respect package config, some may needs to be unstable:
    accept_keywords = set(config.get("aptenodytes", "accept_keywords", fallback="").split())
    accept_keywords.update(env.accept_keywords)

    # filtering the cpvs, we pick only what we want:
    cpvs: List[str] = list()
    for next_cpv in candidate_cpvs:
        # don't include live packages:
        if "-9999" in next_cpv:
            continue

        # keyword match test:
        try:
            keywords = set(env.portdbapi.aux_get(next_cpv, ["KEYWORDS"])[0].split())
        except PortageKeyError:
            continue
        if len(keywords.intersection(accept_keywords)) == 0:
            continue
        cpvs.append(next_cpv)

    # falling back...
    if len(cpvs) == 0:
        cpvs.append(cpv)

    # best!
    next_cpv = best(cpvs)
    return cpv_find_repo(env, next_cpv, True), next_cpv

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
    return f"{path.parts[-3]}/{path.parts[-1].removesuffix(".ebuild")}"

def collect_ebuild_package(env: WorkingEnvironment, repo_name: str, cpv: str) -> EbuildPackage:
    # check rev, if the package doesn't contains it, then don't make it:
    rev: Optional[str]
    category, name, ver, rev = catpkgsplit(cpv)
    if not cpv.endswith(rev):
        rev = None
    version = Version(ver, rev)

    # fetching things from ebuild:
    ebuild = str(env.repos_path / repo_name / cpv_to_path(cpv))
    try:
        settings = portage.config(clone=portage.settings)
        settings.setcpv(cpv, mydb=env.portdbapi)
        doebuild.doebuild_environment(ebuild, "depend", settings=settings, db=env.portdbapi)
        keywords = set(settings["KEYWORDS"].split())
    except (PortageKeyError, UnsupportedAPIException):
        keywords = env.accept_keywords

    # verbosity package...
    return EbuildPackage(name, version, ebuild, repo_name, cpv, keywords)

OVERLAY_REGEX = re.compile(r"pkg_overlay(\s[\-\w\s]+)?")
def parse_pkg_overlay(text: str, default: str) -> Optional[str]:
    match = OVERLAY_REGEX.search(text)
    if match is None:
        return None
    args = match[0].split()
    for i, arg in enumerate(args):
        if arg == "--repo":
            return args[i+1]
    return default

def collect_overlay_package(env: WorkingEnvironment, cpv: str) -> OverlayPackage:
    # TODO: PORTDIR_OVERLAY
    ebuild_package = collect_ebuild_package(env, env.repo_name, cpv)
    ebuild = ebuild_package.source
    assert ebuild is not None

    # deducing the comment config and actual overlay:
    config = ConfigParser()
    repo_overlay: Optional[str] = None
    with open(ebuild, "r") as reader:
        lines = reader.readlines()
    for line in lines:
        if line.startswith("# [aptenodytes]"):
            config.read_string(line.replace(" ", "\n"))
        elif repo_overlay is None:
            repo_overlay = parse_pkg_overlay(line, env.default_repo_name)

    # hey i'm over laying:
    return OverlayPackage(*astuple(ebuild_package), repo_overlay, config)

def collect_profile_packages(env: WorkingEnvironment, fullpath: Path) -> List[ProfilePackage]:
    # reading the whole profile package list:
    packages: List[ProfilePackage] = list()
    with open(fullpath, "r") as reader:
        lines = reader.readlines()

    # parsing the list into ebuild packages:
    config_text: Optional[str] = None
    for line in lines:
        if line.startswith("# [aptenodytes]"):
            config_text = line.replace(" ", "\n")
        cpv = line.removeprefix("=")
        if cpv == line:
            continue
        cpv = cpv.split(maxsplit=1)[0]

        # it may not exists in the repo, so we need searching:
        repo_name = cpv_find_repo(env, cpv, False)

        # as always, we hint by the comment config:
        ebuild_package = collect_ebuild_package(env, repo_name, cpv)
        config = ConfigParser()
        if config_text is not None:
            config.read_string(config_text)
            config_text = None
        profile_package = ProfilePackage(*astuple(ebuild_package), config)
        packages.append(profile_package)

    # TODO: List[OverlayPackage]?
    return packages

def collect_repology_package() -> RepologyPackage:
    return None

def main():
    # prepare things up:
    env = WorkingEnvironment()
    overlay_packages: List[OverlayPackage] = list()
    profile_packages: List[ProfilePackage] = list()

    # obtain every normal packages, filter only really overlays:
    repo_path = env.repos_path / env.repo_name
    for ebuild_path in repo_path.glob("**/*.ebuild", recurse_symlinks=True):
        cpv = path_to_cpv(ebuild_path)
        package = collect_overlay_package(env, cpv)
        if package.repo_overlay is None:
            continue
        overlay_packages.append(package)

    # obtain profiles packages, to show if they needs update:
    repo_profiles_path = repo_path / "profiles"
    for profile in ["package.accept_keywords"]:
        for profile_path in repo_profiles_path.glob(f"**/{profile}", recurse_symlinks=True):
            for package in collect_profile_packages(env, profile_path):
                profile_packages.append(package)

    # find the best cpv, check if any updates:
    for package in overlay_packages + profile_packages:
        ebuild_package: EbuildPackage = package
        repo_name, cpv = find_best_cpv(env, ebuild_package.cpv, package.config)
        if cpv == ebuild_package.cpv:
            continue

        # we might go a little bit too far:
        pin_until_stable = package.config.getboolean("aptenodytes", "pin_until_stable", fallback=False)
        if pin_until_stable and pkgcmp(pkgsplit(ebuild_package.cpv), pkgsplit(cpv)) > 0:
            continue
        print(f"{ebuild_package.cpv} ({ebuild_package.repo_name}) -> {cpv} ({repo_name})")

if __name__ == "__main__":
    main()

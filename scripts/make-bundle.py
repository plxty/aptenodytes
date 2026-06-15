#!/usr/bin/env python3

import os
import sys
from pathlib import Path
from typing import Optional, Any, List, Self
from collections.abc import Callable
from subprocess import check_call
import json
import mimetypes
import urllib.parse
import urllib.request
import urllib.error
from dataclasses import dataclass, field
from portage.versions import catpkgsplit


def github_request(
    url: str,
    method: str,
    data: Optional[bytes],
    content_type: Optional[str],
    token: str,
) -> Optional[Any]:
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2026-03-10",
        "User-Agent": "github.com/plxty/aptenodytes",
    }
    if content_type:
        headers["Content-Type"] = content_type

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req) as resp:
        body = resp.read()
        if not body:
            return None
        return json.loads(body)


def github_upload(tag: str, name: str, path: Path, token: str) -> Optional[Any]:
    tag = urllib.parse.quote(tag, safe="")
    url = f"https://api.github.com/repos/plxty/aptenodytes/releases/tags/{tag}"
    resp = github_request(url, "GET", None, None, token)
    if resp is None:
        return None

    # https://uploads.github.com/repos/OWNER/REPO/releases/ID/assets{?name,label}
    url = resp["upload_url"].split("{", 1)[0]
    url = f"{url}?{urllib.parse.urlencode({'name': name})}"
    with open(path, "rb") as f:
        data = f.read()
    return github_request(
        url,
        "POST",
        data,
        mimetypes.guess_type(name)[0] or "application/octet-stream",
        token,
    )


def call(commands: List[str], cwd: Path) -> None:
    print(f">>> Running {' '.join(commands)}...")
    check_call(commands, cwd=cwd)


@dataclass
class Vendor:
    name: str
    version: str
    tag: Optional[str] = None
    flight: Optional[Callable[[Path], List[Path]]] = None

    def __post_init__(self: Self) -> None:
        if self.tag is None:
            self.tag = f"v{self.version}"


@dataclass
class GoVendor(Vendor):
    xform: Optional[str] = None
    pre_compress_hooks: List[List[str]] = field(default_factory=list)

    def _flight(self: Self, cwd: Path) -> List[Path]:
        # treat some special workdir:
        artifact = f"{self.name}-{self.version}-vendor.tar.xz"
        if self.xform is None:
            self.xform = f"{self.name}-{self.version}"

        call(["go", "mod", "vendor"], cwd)
        for hook in self.pre_compress_hooks:
            call(hook, cwd)
        call(
            [
                "tar",
                "-caf",
                artifact,
                "--owner=root",
                "--group=root",
                f"--xform=s/{cwd.name}/{self.xform}/",
                "-C",
                str(cwd.parent),
                f"{cwd.name}/vendor",
            ],
            cwd,
        )
        return [cwd / artifact]

    def __post_init__(self: Self) -> None:
        super().__post_init__()
        if self.flight is None:
            self.flight = lambda cwd: self._flight(cwd)


def store_vendors(vendor: Vendor, cwd: Path) -> List[Path]:
    assert vendor.tag is not None
    assert vendor.flight is not None

    # check the git out:
    call(["git", "reset", "--hard"], cwd)
    call(["git", "clean", "-fdx"], cwd)
    call(["git", "fetch", "-fPp"], cwd)
    call(["git", "checkout", vendor.tag], cwd)

    # do vendors:
    return vendor.flight(cwd)


def main() -> None:
    # steal content from file if it is:
    token = os.environ.get("GITHUB_TOKEN")
    if token is None:
        with open(".github_token", "r") as reader:
            token = reader.read().strip()

    # doing work:
    cpv, git_dir, *_ = sys.argv[1:]
    cat, pkgname, version, _ = catpkgsplit(cpv)
    match f"{cat}/{pkgname}":
        case "app-office/lark-cli":
            vendor = GoVendor(
                pkgname,
                version,
                xform=f"cli-{version}",
                pre_compress_hooks=[
                    ["python3", "scripts/fetch_meta.py"],
                    ["cp", "internal/registry/meta_data.json", "vendor"],
                ],
            )
        # TODO: defaults to fetch from ebuild?
        case _:
            raise

    # TODO: cleanup previous?
    print(f">>> Vendoring {cpv}...")
    for path in store_vendors(vendor, Path(git_dir)):
        print(f">>> Uploading {str(path)}...")
        resp = github_upload("dist", path.name, path, token)
        if resp is None:
            print("!!! Failed to upload the artifact")
        else:
            print(f">>> Successfully upload to {resp['browser_download_url']}")


if __name__ == "__main__":
    main()

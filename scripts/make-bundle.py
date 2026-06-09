#!/usr/bin/env python3

import os
import sys
from pathlib import Path
from typing import Optional, Any
import json
import mimetypes
import urllib.parse
import urllib.request
import urllib.error


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


def github_upload(tag: str, name: str, path: Path, token: str) -> bool:
    tag = urllib.parse.quote(tag, safe="")
    url = f"https://api.github.com/repos/plxty/aptenodytes/releases/tags/{tag}"
    resp = github_request(url, "GET", None, None, token)
    if resp is None:
        return False

    # https://uploads.github.com/repos/OWNER/REPO/releases/ID/assets{?name,label}
    url = resp["upload_url"].split("{", 1)[0]
    url = f"{url}?{urllib.parse.urlencode({'name': name})}"
    with open(path, "rb") as f:
        data = f.read()
    resp = github_request(
        url,
        "POST",
        data,
        mimetypes.guess_type(name)[0] or "application/octet-stream",
        token,
    )
    if resp is None:
        return False

    print(json.dumps(resp, indent=2))
    return True


def main():
    # steal content from file if it is:
    token = os.environ.get("GITHUB_TOKEN")
    if token is None:
        with open(".github_token", "r") as reader:
            token = reader.read().strip()

    # doing work:
    name, *_ = sys.argv[1:]
    path = Path(name)
    github_upload("dist", path.name, path, token)


if __name__ == "__main__":
    main()

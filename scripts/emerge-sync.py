#!/usr/bin/env python3

import sys
from os import path
import portage
from portage.package.ebuild.config import config as ebuild_config
from subprocess import check_call
from shutil import rmtree


def main():
    # enforce sync mode to allow nonexistent directory:
    portage._sync_mode = True
    config = ebuild_config()

    # check if repository changed from rsync to git or vise versa:
    for repo in config.repositories:
        if repo.sync_type is None:
            continue

        sync_type = "rsync"
        if path.exists(f"{repo.location}/.git/index"):
            sync_type = "git"

        if path.exists(repo.location) and sync_type != repo.sync_type:
            print(f">>> Resetting repository {repo.name}...")
            rmtree(repo.location)
        else:
            print(f">>> Refreshing repository {repo.name}...")

        # real the work:
        check_call(["emerge", "--sync", *sys.argv[1:], repo.name])


if __name__ == "__main__":
    main()

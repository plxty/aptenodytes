#!/usr/bin/env bash

set -ue

IGLU_ID="${1}"
EPREFIX="${2}"

# bring in guse or other stuffs:
cd "$(dirname "${BASH_SOURCE[0]}")"
EAPI="8"
source ../eclass/dirty-deeds.eclass

# check if is a prefix or gentoo install
USE="${USE:-} "
if grep -q prefix "../profiles/iglu/${IGLU_ID}/parent"; then
  USE+="prefix "
fi

# for many users:
while read -r user; do
  USE+="iglu_lives_${user} "
done < <(awk -F/ '$(NF-1) == "superego" {print $NF}' "../profiles/iglu/${IGLU_ID}/parent")

erun() {
  if guse prefix; then
    # shellcheck disable=SC2016
    "${EPREFIX}/usr/bin/bash" -l -c 'exec "${@}"' -- env "${@}"
  else
    echo "unimplemented"
    # arch-chroot "${EPREFIX}"... ?
    exit 1
  fi
}

fire_repositories() {
  local use_git=false
  if erun git -v >/dev/null; then
    use_git=true
  fi

  local gentoo_repo="${EPREFIX}/var/db/repos/gentoo"
  local aptenodytes_repo="${EPREFIX}/var/db/repos/aptenodytes"

  # in prefix, the repo will be set up after bootstrap-prefix.sh, so baremetal only:
  if ! guse prefix; then
    if ${use_git} && [[ ! -e "${gentoo_repo}/.git/index" ]]; then
      rm -rf "${gentoo_repo}"
      erun emerge --sync --quiet gentoo
    elif [[ ! -e "${gentoo_repo}/sys-apps/portage/Manifest" ]]; then
      erun emerge-webrsync -q
    fi
  fi

  # sync other things as well here in git:
  if ${use_git} && [[ ! -e "${aptenodytes_repo}/.git/index" ]]; then
    rm -rf "${aptenodytes_repo}"
    erun emerge --sync --quiet
  elif [[ ! -e "${aptenodytes_repo}/scripts/burn.sh" ]]; then
    mkdir -p "${aptenodytes_repo}"
    rsync -ap --exclude .git .. "${aptenodytes_repo}"
  fi
}

# TODO: many stages are missing now :(
fire_repositories

if [[ ! -e "${EPREFIX}/etc/portage/repos.conf/aptenodytes.conf" ]]; then
  mkdir -p "${EPREFIX}/etc/portage/repos.conf"
  {
    echo "[aptenodytes]"
    echo "location = ${EPREFIX}/var/db/repos/aptenodytes"
  } > "${EPREFIX}/etc/portage/repos.conf/aptenodytes.conf"
fi

if [[ "$(readlink "${EPREFIX}/etc/portage/make.profile")" != *"aptenodytes/profiles/iglu/${IGLU_ID}" ]]; then
  erun eselect profile set "aptenodytes:iglu/${IGLU_ID}"
fi

# [[ -e ]] doesn't support glob, so test here:
if ! test -e "${EPREFIX}/var/db/pkg/sci-misc/aptenodytes-"*"/repository"; then
  erun emerge -1 sci-misc/aptenodytes
fi

# now try to sync the repo with git to ensure we've setup:
fire_repositories

# TODO: make a better marker:
if guse prefix && ! grep -q "like we've no prefix" "${EPREFIX}/usr/lib/python"*"/site-packages/portage/dbapi/vartree.py"; then
  erun emerge -1 sys-apps/portage
fi

# update-the-world
erun emerge -UND @world

# setting password if needed:
if ! guse prefix; then
  for flag in $USE; do
    if [[ "${flag}" != "iglu_lives_"* ]]; then
      continue
    fi
    username="${flag#iglu_lives_}"
    if [[ "$(erun passwd -S "${username}" | awk '{print $2}')" == "NP" ]]; then
      passwd "${username}"
    fi
  done
fi

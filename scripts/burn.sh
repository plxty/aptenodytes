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
    arch-chroot "${EPREFIX}" "${@}"
  fi
}

fire_repositories() {
  local refresh="${1:-false}"
  if "${refresh}"; then
    echo ">>> Refreshing repositories..."
  else
    echo ">>> Initializing repositories..."
  fi

  local use_git=false
  if erun git -v >/dev/null; then
    use_git=true
  fi

  local gentoo_repo="${EPREFIX}/var/db/repos/gentoo"
  local aptenodytes_repo="${EPREFIX}/var/db/repos/aptenodytes"

  # in prefix, the repo will be set up after bootstrap-prefix.sh, so baremetal only:
  if ! guse prefix; then
    local refresh_gentoo="${refresh}"
    if ${use_git} && [[ ! -e "${gentoo_repo}/.git/index" ]]; then
      rm -rf "${gentoo_repo}"
      refresh_gentoo=true
    elif [[ ! -e "${gentoo_repo}/sys-apps/portage/Manifest" ]]; then
      refresh_gentoo=true
    fi

    if ${refresh_gentoo}; then
      if ${use_git}; then
        erun emerge --sync --quiet
      else
        erun emerge-webrsync -q
      fi
    fi
  elif "${refresh}" && "${use_git}"; then
    # sync prefix directly:
    erun emerge --sync --quiet
  fi

  # always rsync myself:
  if ${refresh} || [[ ! -e "${aptenodytes_repo}/scripts/burn.sh" ]]; then
    mkdir -p "${aptenodytes_repo}"
    rsync -a --delete --exclude .git .. "${aptenodytes_repo}"
  fi
}

# TODO: many stages are missing now :(
fire_repositories

if [[ ! -e "${EPREFIX}/etc/portage/repos.conf/aptenodytes.conf" ]]; then
  echo ">>> Making temporary repos.conf..."
  mkdir -p "${EPREFIX}/etc/portage/repos.conf"
  {
    echo "[aptenodytes]"
    if guse prefix; then
      echo "location = ${EPREFIX}/var/db/repos/aptenodytes"
    else
      echo "location = /var/db/repos/aptenodytes"
    fi
  } > "${EPREFIX}/etc/portage/repos.conf/aptenodytes.conf"
fi

if [[ "$(readlink "${EPREFIX}/etc/portage/make.profile")" != *"aptenodytes/profiles/iglu/${IGLU_ID}" ]]; then
  echo ">>> Selecting profile for ${IGLU_ID}..."
  erun eselect profile set "aptenodytes:iglu/${IGLU_ID}"
fi

# [[ -e ]] doesn't support glob, so test here:
if ! test -e "${EPREFIX}/var/db/pkg/sci-misc/aptenodytes-"*"/repository"; then
  echo ">>> Merging sci-misc/aptenodytes..."
  erun emerge -1 sci-misc/aptenodytes
fi

# now try to sync the repo with git to ensure we've setup:
fire_repositories true

# TODO: make a better marker:
if guse prefix && ! grep -q "like we've no prefix" "${EPREFIX}/usr/lib/python"*"/site-packages/portage/dbapi/vartree.py"; then
  echo ">>> Re-merging pacthed sys-apps/portage..."
  erun emerge -1 sys-apps/portage
fi

# update-the-world
echo ">>> Burning..."
erun emerge -uND @world

# setting password if needed:
if ! guse prefix; then
  for flag in $USE; do
    if [[ "${flag}" != "iglu_lives_"* ]]; then
      continue
    fi
    username="${flag#iglu_lives_}"
    if [[ "$(erun passwd -S "${username}" | awk '{print $2}')" == "NP" ]]; then
      echo ">>> Resetting password for user ${username}..."
      passwd "${username}"
    fi
  done
fi

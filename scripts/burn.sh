#!/usr/bin/env bash

set -ue

die() {
	echo "!!! ${*}"
	exit 1
}

# [--opts...] [iglu_id] [eprefix]
IGLU_ID="$(hostname)"
EPREFIX="/"
SKIP_REFRESH=false
ASK=false
while [[ "${1:-}" != "" ]]; do
	case "${1}" in
		"--skip-refresh") SKIP_REFRESH=true ;;
		"--ask") ASK=true ;;
		"--")
			shift 1
			break
			;;
		*)
			if [[ "${EPREFIX}" != "/" ]]; then
				IGLU_ID="${EPREFIX}"
			fi
			EPREFIX="${1}"
			;;
	esac
	shift 1
done

EPREFIX="$(realpath "${EPREFIX}")"
if [[ "${IGLU_ID}" == "" || "${EPREFIX}" == "" ]]; then
	die "Invalid arguments"
fi

# bring in guse or other stuffs:
cd "$(dirname "${BASH_SOURCE[0]}")"
EAPI="8"
source ../eclass/dirty-deeds.eclass

# check if is a prefix or gentoo install
USE="${USE:-} "
if grep -q prefix "../profiles/iglu/${IGLU_ID}/parent"; then
	USE+="prefix "
fi
case "$(awk '$2 == "'"iglu/${IGLU_ID}"'" {print $1}' ../profiles/profiles.desc)" in
	"arm64-macos") USE+="prefix-guest " ;;
esac

# for many users:
while read -r user; do
	USE+="iglu_lives_${user} "
done < <(awk '-F[:/]' '$(NF-1) == "superego" {print $NF}' "../profiles/iglu/${IGLU_ID}/parent")

erun() {
	if guse prefix; then
		# shellcheck disable=SC2016
		"${EPREFIX}/usr/bin/bash" -c "source '${EPREFIX}/etc/profile';"'exec "${@}"' -- env "${@}"
	elif [[ "${EPREFIX}" == "/" ]]; then
		"${@}"
	else
		arch-chroot "${EPREFIX}" "${@}"
	fi
}

fire_repositories() {
	local refresh="${1:-false}"
	local use_git=false
	if erun git -v >/dev/null; then
		use_git=true
	fi

	local gentoo_repo="${EPREFIX}/var/db/repos/gentoo"
	if guse prefix-guest; then
		gentoo_repo="${EPREFIX}/var/db/repos/gentoo_prefix"
	fi

	# note for gentoo_prefix repo (darwin use it), it's rsync only, don't rm
	local refresh_gentoo="${refresh}"
	if ${use_git} && [[ ! -e "${gentoo_repo}/.git/index" ]] && ! guse prefix-guest; then
		rm -rf "${gentoo_repo}"
		refresh_gentoo=true
	elif [[ ! -e "${gentoo_repo}/sys-apps/portage/Manifest" ]]; then
		refresh_gentoo=true
	fi

	if ${refresh_gentoo} && ! ${SKIP_REFRESH}; then
		if ${use_git}; then
			echo ">>> Refreshing repositories..."
			erun emerge --sync --quiet
		else
			echo ">>> Initializing repositories..."
			erun emerge-webrsync -q
		fi
	fi

	# always rsync myself, note the exclude rules (@see man 1 rsync)
	local aptenodytes_repo="${EPREFIX}/var/db/repos/aptenodytes"
	if ${refresh} || [[ ! -e "${aptenodytes_repo}/scripts/burn.sh" ]]; then
		mkdir -p "${aptenodytes_repo}"
		rsync -aC --exclude ".*" --delete .. "${aptenodytes_repo}"
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
	} >"${EPREFIX}/etc/portage/repos.conf/aptenodytes.conf"
fi

if [[ "$(readlink "${EPREFIX}/etc/portage/make.profile")" != *"aptenodytes/profiles/iglu/${IGLU_ID}" ]]; then
	echo ">>> Selecting profile for ${IGLU_ID}..."
	erun eselect profile set "aptenodytes:iglu/${IGLU_ID}"
fi

if guse prefix && ! guse prefix-guest && [[ ! -L "${EPREFIX}/usr/sbin" ]]; then
	echo ">>> Fixing merge-usr layout for prefix..."
	erun emerge -1 sys-apps/merge-usr
	erun merge-usr --prefix "${EPREFIX}"
fi

if guse prefix && [[ ! -e "${EPREFIX}/home" ]]; then
	for flag in $USE; do
		if [[ "${flag}" != "iglu_lives_"* ]]; then
			continue
		fi
		username="${flag#iglu_lives_}"
		if hash finger 2>/dev/null; then
			homedest="$(finger "${username}" | awk '/^Directory/ {print $2}')"
		elif hash getent 2>/dev/null; then
			homedest="$(getent passwd "${username}" | cut -d: -f6)"
		else
			die "unable to get home for prefix user ${username}"
		fi
	done
	echo ">>> Symlinking home to ${username}..."
	ln -s "${homedest}" "${EPREFIX}/home"
fi

# [[ -e ]] doesn't support glob, so test here:
if ! test -e "${EPREFIX}/var/db/pkg/sci-misc/aptenodytes-"*"/repository"; then
	echo ">>> Merging sci-misc/aptenodytes..."
	erun emerge -1 sci-misc/aptenodytes
fi

# now try to sync the repo with git to ensure we've setup:
fire_repositories true

# update-the-world if !shell-instead
if [[ "${*}" != "" ]]; then
	echo ">>> Spawning ${*}..."
	erun "${@}"
else
	echo ">>> Burning..."
	if "${ASK}"; then
		erun emerge -uNDva @world
	else
		erun emerge -uND @world
	fi
fi

# setting password if needed:
if ! guse prefix; then
	for flag in $USE; do
		if [[ "${flag}" != "iglu_lives_"* ]]; then
			continue
		fi
		username="${flag#iglu_lives_}"
		if [[ "$(erun passwd -S "${username}" | awk '{print $2}')" != "P" ]]; then
			echo ">>> Resetting password for user ${username}..."
			erun passwd "${username}"
		fi
	done
fi

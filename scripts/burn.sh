#!/usr/bin/env bash

set -ue

die() {
	echo "!!! ${*}"
	exit 1
}

# [--opts...] [iglu_id] [eprefix]
IGLU_ID="$(hostname)"
EPREFIX=
SKIP_REFRESH=false
YES=false
while [[ "${1:-}" != "" ]]; do
	case "${1}" in
	"--help") die "${0} [--skip-refresh] [--yes] [IGLU_ID|${IGLU_ID}] [EPREFIX] [-- ...]" ;;
	"--skip-refresh") SKIP_REFRESH=true ;;
	"--yes") YES=true ;;
	"--")
		shift 1
		break
		;;
	"-"*) die "Unsupported argument ${1}" ;;
	*)
		if [[ "${EPREFIX}" != "" ]]; then
			IGLU_ID="${EPREFIX}"
		fi
		EPREFIX="${1}"
		;;
	esac
	shift 1
done

# bring in guse or other stuffs:
cd "$(dirname "${BASH_SOURCE[0]}")"
EAPI="8"
source ../eclass/dirty-deeds.eclass

# sanity:
if [[ ! -e "../profiles/iglu/${IGLU_ID}" ]]; then
	die "Invalid IGLU_ID: ${IGLU_ID}"
fi
if [[ "${EPREFIX}" != "" ]]; then
	EPREFIX="$(realpath "${EPREFIX}")"
	if [[ "${EPREFIX}" == "" ]]; then
		die "Invalid EPREFIX: ${EPREFIX}"
	fi
	if [[ "${EPREFIX}" == "/" ]]; then
		EPREFIX=
	fi
fi

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
	local args=("${1}")
	if ! "${YES}"; then
		case "${args[0]}" in
		"emerge") args+=("-va") ;;
		esac
	fi
	args+=("${@:2}")

	if guse prefix; then
		# shellcheck disable=SC2016
		"${EPREFIX}/usr/bin/bash" -c "source '${EPREFIX}/etc/profile';"'exec "${@}"' \
			-- env "${args[@]}"
	elif [[ "${EPREFIX}" == "" ]]; then
		"${args[@]}"
	else
		arch-chroot "${EPREFIX}" "${args[@]}"
	fi
}

# unify with prefix:
if guse prefix-guest; then
	REPOS_GENTOO="gentoo_prefix"
else
	REPOS_GENTOO="gentoo"
fi
if [[ ! -e "${EPREFIX}/var/db/repos/${REPOS_GENTOO}/sys-apps/portage/Manifest" ]]; then
	echo ">>> Initializing repositories..."
	erun emerge-webrsync -q
fi

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

# make me the latest shiny cool boy, @see man 1 rsync
mkdir -p "${EPREFIX}/var/db/repos/aptenodytes"
rsync -aC --exclude ".*" --delete .. "${EPREFIX}/var/db/repos/aptenodytes"

if [[ "$(readlink "${EPREFIX}/etc/portage/make.profile")" != *"aptenodytes/profiles/iglu/${IGLU_ID}" ]]; then
	echo ">>> Selecting profile for ${IGLU_ID}..."
	erun eselect profile set "aptenodytes:iglu/${IGLU_ID}"
fi

if guse prefix && [[ ! -e "${EPREFIX}/home" ]]; then
	# for prefix we're using the acutal home:
	# TODO: make a prefix-isolation to store everything elsewhere than home?
	username="$(whoami)"
	if hash getent 2>/dev/null; then
		homedest="$(getent passwd "${username}" | cut -d: -f6)"
	elif hash finger 2>/dev/null; then
		homedest="$(finger "${username}" | awk '/^Directory/ {print $2}')"
	else
		die "unable to get home for prefix user ${username}"
	fi
	echo ">>> Symlinking home to ${username}..."
	ln -s "$(realpath "${homedest}")" "${EPREFIX}/home"
fi

if guse prefix && ! guse prefix-guest && [[ ! -L "${EPREFIX}/usr/sbin" ]]; then
	echo ">>> Fixing merge-usr layout for prefix..."
	erun emerge -1 sys-apps/merge-usr
	erun merge-usr --prefix "${EPREFIX}"
fi

# [[ -e ]] doesn't support glob, so test here:
if ! test -e "${EPREFIX}/var/db/pkg/sci-misc/aptenodytes-"*"/repository"; then
	echo ">>> Merging sci-misc/aptenodytes..."
	erun emerge -1 sci-misc/aptenodytes
fi

# now try to sync the repo with git to ensure we've setup:
if ! "${SKIP_REFRESH}"; then
	erun "${PWD}/keep-in-sync.py" --pretend
fi

# update-the-world if !shell-instead
if [[ "${*}" != "" ]]; then
	echo ">>> Spawning ${*}..."
	erun "${@}"
else
	echo ">>> Burning..."
	erun emerge -uND @world
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

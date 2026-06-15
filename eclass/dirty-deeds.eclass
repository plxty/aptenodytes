if [[ -z ${_DIRTY_DEEDS_ECLASS:-} ]]; then

case "${EAPI}" in
  "7"|"8"|"9") ;;
  *) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

guse() {
  # use in global-scope...
  for flag in $USE; do
    if [[ "${1}" == "${flag}" ]]; then
      return 0
    fi
  done
  # the USE is deduced from profile, not packages, so safe:
  return 1
}

pkg_overlay() {
  # defaults to overlay the main repo:
  local repo="gentoo"
  if [[ "${1:-}" == "--repo" ]]; then
    repo="${2}"
    shift 2
  elif guse prefix-guest; then
    repo="gentoo_prefix"
  fi

  # in global scope, the EPREFIX seems not set yet:
  local layer="${PORTAGE_CONFIGROOT}/var/db/repos/${repo}/${CATEGORY}/${PN}"

  # should eval in the outside, to keep things:
  local text="$(<"${layer}/${PF}.ebuild")"
  if [[ "${text}" == "" ]]; then
    die "overlay for ${PF}::${repo} doesn't exist, maybe you need updates?"
  fi

  # workaround for FILESDIR (readonly):
  echo "OLDFILESDIR='${layer}/files'"
  echo -n "${text//FILESDIR/OLDFILESDIR}"
}

class_overlay() {
  # defaults to overlay the main repo:
  local repo="gentoo"
  if [[ "${1:-}" == "--repo" ]]; then
    repo="${2}"
    shift 2
  elif guse prefix-guest; then
    repo="gentoo_prefix"
  fi

  local text="$(<"${PORTAGE_CONFIGROOT}/var/db/repos/${repo}/eclass/${ECLASS}.eclass")"
  echo -n "${text}"
}

escript() {
  local script_dir="${PORTAGE_CONFIGROOT}/var/db/repos/aptenodytes/scripts"
  local exe="${1}"
  shift 1

  "${script_dir}/${exe}" "${@}" || die
}

userinsinto() {
  export __E_USERINSDESTTREE="${1}"
}

userdoins() {
  local users=()
  for flag in $USE; do
    if [[ "${flag}" != "iglu_lives_"* ]]; then
      continue
    fi

    local username="${flag#iglu_lives_}"
    local groupname="${username}" homedest=
    if use prefix; then
      username="${PORTAGE_USERNAME}"
      groupname="${PORTAGE_GRPNAME}"
    fi

    if [[ "${ARCH}" == *"-macos" ]]; then
      homedest="$(finger "${username}" | awk '/^Directory/ {print $2}')"
    else
      homedest="$(getent passwd "${username}" | cut -d: -f6)"
    fi

    if use prefix; then
      # Make a relative path to passing by the checks, dirty enough:
      homedest="/$(realpath -s --relative-to="${EPREFIX}" "${homedest}")"
    fi

    users+=("${username}"$'\n'"${groupname}"$'\n'"${homedest}")
  done

  for user in "${users[@]}"; do
    IFS=$'\n' read -d'' -r username groupname homedest <<< "$user"
    local target="${homedest}/${__E_USERINSDESTTREE}"

    # dodir first to try to fix the intermediat directories permissions...
    diropts --owner "${username}" --group "${groupname}"
    dodir "$(dirname "${target}")"
    insopts --owner "${username}" --group "${groupname}"
    insinto "${target}"
    doins "${@}"

    diropts
    insopts
  done
}

# copy of systemd_enable_service, add ability with template:
systemd_enable_service_template() {
  debug-print-function ${FUNCNAME} "$@"

  [[ ${#} -eq 3 ]] || die "Synopsis: systemd_enable_service_template target service template"

  local target=${1}
  local service=${2}
  local template=${3}
  local ud=$(_systemd_unprefix systemd_get_systemunitdir)
  local destname=${service##*/}

  dodir "${ud}"/"${target}".wants && \
  dosym ../"${template}" "${ud}"/"${target}".wants/"${destname}"
}

_DIRTY_DEEDS_ECLASS=1
fi

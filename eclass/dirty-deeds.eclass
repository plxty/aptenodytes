if [[ -z ${_DIRTY_DEEDS_ECLASS} ]]; then
_DIRTY_DEEDS_ECLASS=1

case "${EAPI}" in
  "8"|"9") ;;
  *) die "${ECLASS}: EAPI ${EAPI:-0} not supported" ;;
esac

suse() {
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
  local gentoo_repo="gentoo"
  if suse prefix-guest; then
    gentoo_repo="gentoo_prefix"
  fi
  # in global scope, the EPREFIX seems not set yet:
  local layer="${PORTAGE_CONFIGROOT}/var/db/repos/${gentoo_repo}/${CATEGORY}/${PN}"
  # workaround for FILESDIR (readonly):
  export OLDFILESDIR="${layer}/files"
  local text="$(<"${layer}/${PF}.ebuild")"
  eval "${text//FILESDIR/OLDFILESDIR}"
}

class_overlay() {
  # unify with pkg_overlay?
  local gentoo_repo="gentoo"
  if suse prefix-guest; then
    gentoo_repo="gentoo_prefix"
  fi
  source "${PORTAGE_CONFIGROOT}/var/db/repos/${gentoo_repo}/eclass/${ECLASS}.eclass"
}

userinsinto() {
  export __E_USERINSDESTTREE="${1}"
}

userdoins() {
  # name group home
  local users=()
  if use prefix && use "iglu_lives_${PORTAGE_USERNAME}"; then
    # TODO: more robust way...
    if [[ "${ARCH}" == *"-macos" ]]; then
      local homedest="/Users/${PORTAGE_USERNAME}"
    else
      local homedest="/home/${PORTAGE_USERNAME}"
    fi
    # Make a relative path to passing by the checks, dirty enough:
    homedest="/$(realpath -s --relative-to="${EPREFIX}" "${homedest}")"
    users+=("${PORTAGE_USERNAME}"$'\n'"${PORTAGE_GRPNAME}"$'\n'"${homedest}")
  else
    for flag in $USE; do
      if [[ "${flag}" != "iglu_lives_"* ]]; then
        continue
      fi
      local username="${flag#iglu_lives_}"
      users+=("${username}"$'\n'"${username}"$'\n'"$(getent passwd "${user}" | cut -d: -f6)")
    done
  fi

  for user in "${users[@]}"; do
    IFS=$'\n' read -d'' -r username groupname homedest <<< "$user"
    insinto "${homedest}/${__E_USERINSDESTTREE}"
    insopts --owner "${username}" --group "${groupname}"
    doins "${@}"
  done
}
fi

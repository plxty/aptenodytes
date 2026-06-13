EAPI="8"

# we simply can't make a overlay of elcass which forces gentoo to obey.
# so only changing the build is possible...
# @see kernel-build.eclass, mydbapi.repositories.get_repo_for_location(...).porttrees
inherit dirty-deeds
eval "$(pkg_overlay)"

# hijacking olddefconfig to support localmodconfig as well:
# @see kernel-build_src_configure
IUSE="${IUSE} modprobed-db"
BDEPEND+="
  modprobed-db? ( sys-kernel/modprobed-db )
"

# is a binary: portage/bin/ebuild-helpers/emake
emake() {
  local emake_arg
  local option_args=()
  local lsmod=
  for emake_arg in "${@}"; do
    if [[ "${emake_arg}" == "olddefconfig" ]]; then
      lsmod="/etc/kernel/modprobed.db"
    else
      option_args+=("${emake_arg}")
    fi
  done

  command emake "${@}" || die
  if [[ "${lsmod}" != "" && -e "${lsmod}" ]] && use modprobed-db; then
    if [[ ! -e "${lsmod}" ]]; then
      ewarn "USE=modprobed-db but ${lsmod} isn't inplace, will build full modules"
    else
      command emake "${option_args[@]}" "LSMOD=${lsmod}" localmodconfig || die
    fi
  fi
}

# we're making a uki image here, so depends on firmware unconditionally.
# because, in kernel build, we need hardcode the firmware there...
# @see INITRD_PACKAGES, reason why !generic-uki, is that pulls in a generic initramfs,
# and we don't want a initramfs, it pulls too much unneccessary things :/
# the downside is, when ucode updates, the kernel must rebuild to make it work.
BDEPEND+="
  sys-kernel/linux-firmware
  amd64? ( sys-firmware/intel-microcode )
"

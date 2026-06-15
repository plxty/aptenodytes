# https://projects.gentoo.org/pms/latest/pms.html
EAPI="8"
DESCRIPTION="noot-noot, this is a boot"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

# eclasses, if any
# inherit ?

# package build
BDEPEND="!prefix? ( sys-fs/genfstab )"

# we need a clang for darwin platforms, in bootstrap stage:
# and ensures package patches, kernel configs, etc. etc. are ready
RDEPEND="
  sys-apps/portage-p
  arm64-macos? ( llvm-core/clang )
  !prefix? ( sys-kernel/installkernel-p )
"
S="${T}"

src_install() {
  # eselect locale? darwin don't support it...
  insinto /etc/env.d
  {
    echo "# sci-misc/aptenodytes"
    echo "LANG=zh_CN.UTF-8"
    echo "LANGUAGE=zh_CN:en_US"
  } > "${T}/02locale"
  doins "${T}/02locale"

  # we use libiconv for non-glibc, so no need to proceed:
  if use prefix-guest; then
    return
  fi

  # /usr/share/i18n/SUPPORTED
  insinto /etc
  {
    echo "en_US.UTF-8 UTF-8"
    echo "en_US ISO-8859-1"
    echo "zh_CN.GB18030 GB18030"
    echo "zh_CN.GBK GBK"
    echo "zh_CN.UTF-8 UTF-8"
    echo "zh_CN GB2312"
  } > "${T}/locale.gen"
  doins "${T}/locale.gen"
  dosym ../usr/share/zoneinfo/Asia/Shanghai /etc/localtime

  if use prefix; then
    return
  fi

  # non-prefix here:
  echo "${IGLU_ID}" | awk -F. '{print $1}' > "${T}/hostname"
  doins "${T}/hostname"

  genfstab -t PARTUUID / > "${T}/fstab"
  doins "${T}/fstab"
}

pkg_preinst() {
  if use prefix-guest; then
    return
  fi

  if grep -q "LANG=C.UTF-8" "${EPREFIX}/etc/env.d/02locale"; then
    rm -v "${EPREFIX}/etc/env.d/02locale"
  fi

  if grep -q "LANG=C.UTF-8" "${EPREFIX}/etc/locale.conf"; then
    rm -v "${EPREFIX}/etc/locale.conf"
  fi

  if grep -q "man pages" "${EPREFIX}/etc/locale.gen"; then
    rm -v "${EPREFIX}/etc/locale.gen"
  fi

  if use prefix; then
    return
  fi

  if [[ -L /etc/localtime && "$(realpath /etc/localtime)" == "/usr/share/zoneinfo/Factory" ]]; then
    unlink /etc/localtime
  fi

  # /usr/share/baselayout/fstab
  if grep -q manpage /etc/fstab; then
    rm -v /etc/fstab
  fi
}

pkg_postinst() {
  if use prefix-guest; then
    return
  fi

  locale-gen

  if use prefix; then
    return
  fi

  # silence of mount:
  touch /run/systemd/systemd-units-load
}

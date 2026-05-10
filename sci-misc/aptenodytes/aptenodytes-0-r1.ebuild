# https://projects.gentoo.org/pms/latest/pms.html
EAPI="8"
DESCRIPTION="noot-noot, this is a boot"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

# eclasses, if any
# inherit ?

# package build
BDEPEND="!prefix? ( sys-fs/genfstab )"
RDEPEND="
  sys-apps/portage-p
  !prefix? ( sys-kernel/installkernel-p )
"
S="${T}"

src_install() {
  # no need for non-glibc
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

  # https://wiki.archlinux.org/title/Locale
  {
    echo "LANG=zh_CN.UTF-8"
    echo "LANGUAGE=zh_CN:en_US"
  } > "${T}/locale.conf"
  doins "${T}/locale.conf"
  dosym ../usr/share/zoneinfo/Asia/Shanghai /etc/localtime

  if use prefix; then
    return
  fi

  # non-prefix here:
  echo "${IGLU_ID}" > "${T}/hostname"
  doins "${T}/hostname"

  genfstab -t PARTUUID / > "${T}/fstab"
  doins "${T}/fstab"
}

pkg_preinst() {
  if use prefix-guest; then
    return
  fi

  if grep -q "man pages" /etc/locale.gen; then
    rm -v /etc/locale.gen
  fi

  if grep -q "LANG=C.UTF-8" /etc/locale.conf; then
    rm -v /etc/locale.conf
  fi

  if [[ -L /etc/localtime && "$(realpath /etc/localtime)" == "/usr/share/zoneinfo/Factory" ]]; then
    unlink /etc/localtime
  fi

  if use prefix; then
    return
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
}

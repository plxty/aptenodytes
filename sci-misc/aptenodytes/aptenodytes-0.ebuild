# optional, ordered in https://projects.gentoo.org/pms/latest/pms.html
EAPI="9"
KEYWORDS="amd64"
BDEPEND="sys-fs/genfstab"
RDEPEND="
  sys-apps/portage-p
  sys-kernel/installkernel-p
"

# mandatory
DESCRIPTION="noot-noot, this is a boot"
SLOT="0"

S="${T}"

src_install() {
  insinto /etc
  echo "${IGLU_ID}" > "${T}/hostname"
  doins "${T}/hostname"

  genfstab -t PARTUUID / > "${T}/fstab"
  doins "${T}/fstab"

  # /usr/share/i18n/SUPPORTED
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
}

pkg_preinst() {
  # /usr/share/baselayout/fstab
  if grep -q manpage /etc/fstab; then
    rm -v /etc/fstab
  fi

  if grep -q "man pages" /etc/locale.gen; then
    rm -v /etc/locale.gen
  fi

  if grep -q "LANG=C.UTF-8" /etc/locale.conf; then
    rm -v /etc/locale.conf
  fi

  if [[ ! -e /etc/localtime || "$(realpath /etc/localtime)" == "/usr/share/zoneinfo/Factory" ]]; then
    unlink /etc/localtime
  fi
}

pkg_postinst() {
  locale-gen
}

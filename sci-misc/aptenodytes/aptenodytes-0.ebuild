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
}

pkg_preinst() {
  # /usr/share/baselayout/fstab
  if grep -q manpage /etc/fstab; then
    rm -v /etc/fstab
  fi
}

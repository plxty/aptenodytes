# optional, ordered in https://projects.gentoo.org/pms/latest/pms.html
EAPI="9"
KEYWORDS="amd64"
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
}

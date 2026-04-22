EAPI="9"
DESCRIPTION="sudo profile"
KEYWORDS="amd64"
SLOT="0"

RDEPEND="app-admin/sudo"
S="${T}"

src_install() {
  insinto /etc/sudoers.d
  echo "%wheel ALL=(ALL:ALL) ALL" > "${T}/wheel"
  doins "${T}/wheel"
  fperms 0440 /etc/sudoers.d/wheel
}

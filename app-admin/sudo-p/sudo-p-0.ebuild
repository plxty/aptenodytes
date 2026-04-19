EAPI="9"
KEYWORDS="amd64"
RDEPEND="app-admin/sudo"

DESCRIPTION="sudo profile"
SLOT="0"

S="${T}"

src_install() {
  insinto /etc/sudoers.d
  echo "%wheel ALL=(ALL:ALL) ALL" > "${T}/wheel"
  doins "${T}/wheel"
  fperms 0440 /etc/sudoers.d/wheel
}

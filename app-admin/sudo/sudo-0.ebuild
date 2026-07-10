EAPI="9"

inherit dirty-deeds
eval "$(pkg_profile)"

KEYWORDS="amd64"
RDEPEND+=" !app-admin/sudo-p"
S="${T}"

src_install() {
	insinto /etc/sudoers.d
	echo "%wheel ALL=(ALL:ALL) ALL" >"${T}/wheel"
	doins "${T}/wheel"
	fperms 0440 /etc/sudoers.d/wheel
}

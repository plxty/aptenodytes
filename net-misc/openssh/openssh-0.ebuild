EAPI="8"

inherit dirty-deeds systemd
eval "$(pkg_profile)"

KEYWORDS="amd64"
IUSE="server"
S="${T}"

src_install() {
	# firewall? port?
	systemd_enable_service multi-user.target sshd.service

	# presets:
	echo "enable sshd.service" >"${T}/00-sshd.preset"
	insinto "$(systemd_get_systempresetdir)"
	doins "${T}/00-sshd.preset"
}

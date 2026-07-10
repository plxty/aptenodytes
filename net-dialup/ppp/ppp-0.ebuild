EAPI="8"

inherit dirty-deeds systemd
eval "$(pkg_profile)"

KEYWORDS="amd64"
BDEPEND="dev-lang/python"
S="${T}"

src_prepare() {
	default

	escript gen-network.py pppoe pppoe
	for peer in pppoe/*; do
		peer="$(basename "${peer}")"
		echo "enable pppd@${peer}.service" >>01-pppd.preset
	done
}

src_install() {
	insinto /etc/ppp/peers
	doins pppoe/*

	exeinto /etc/ppp
	doexe "${FILESDIR}/ip-link"

	# presets:
	insinto "$(systemd_get_systempresetdir)"
	doins 01-pppd.preset

	insinto "$(systemd_get_systemunitdir)"
	doins "${FILESDIR}/pppd@.service"
	for peer in pppoe/*; do
		peer="$(basename "${peer}")"
		systemd_enable_service_template multi-user.target "pppd@${peer}.service" "pppd@.service"
	done
}

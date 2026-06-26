EAPI="8"
DESCRIPTION="ppp profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPEND="dev-lang/python"
RDEPEND="net-dialup/ppp"
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

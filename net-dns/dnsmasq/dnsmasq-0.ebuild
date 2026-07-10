EAPI="8"

inherit dirty-deeds systemd
eval "$(pkg_profile)"

KEYWORDS="amd64"
BDEPEND="dev-lang/python"
RDEPEND+="
	!net-dns/dnsmasq-p
	sys-apps/systemd:ridgeni[-resolved]
"
S="${T}"

src_prepare() {
	default

	escript gen-network.py dnsmasq .
	dnsmasq -C dnsmasq.conf --test || die "Invalid config found for dnsmasq"

	# defaults resolv:
	IGLU_DOMAIN="$(edomain)" envsubst <"${FILESDIR}/resolv.conf" >resolv.conf

	# presets:
	echo "enable dnsmasq.service" >02-dnsmasq.preset
}

src_install() {
	insinto /etc
	doins dnsmasq.conf resolv.conf

	insinto "$(systemd_get_systempresetdir)"
	doins 02-dnsmasq.preset

	systemd_enable_service multi-user.target dnsmasq.service
}

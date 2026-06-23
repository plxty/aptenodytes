EAPI="8"
DESCRIPTION="mihomo profile"
KEYWORDS="amd64"

inherit systemd

BDEPEND="app-misc/yq"
RDEPEND="
  dev-libs/v2ray-rules-dat-bin
  net-proxy/mihomo
"
S="${T}"

src_install() {
	# FIXME: not finished yet...
	insinto /etc/mihomo
	yq -y config.yaml <"${FILESDIR}/config.yaml"
	doins config.yaml

	dosym /usr/share/geosite/loyalsoldier.dat /etc/mihomo/geosite.dat
	dosym /usr/share/geoip/loyalsoldier.dat /etc/mihomo/geoip.dat
}

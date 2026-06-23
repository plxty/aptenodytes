EAPI="8"
DESCRIPTION="mihomo profile"
KEYWORDS="amd64"
SLOT="0"

inherit systemd

BDEPEND="app-misc/yq"
RDEPEND="
  dev-libs/v2ray-rules-dat-bin
  net-proxy/mihomo
"
S="${T}"

src_install() {
	yq -y >config.yaml <"${FILESDIR}/config.yaml"
	# mocking local test to config:
	{
		echo "proxies:"
		echo "  - name: test"
		echo "    type: ss"
		echo "    server: 1.1.1.1"
		echo "    port: 80"
		echo "    cipher: chacha20-ietf-poly1305"
		echo "    password: my-birthday"
	} >proxy-default.yaml
	# mocking geo to prevent downloading:
	ln -s /usr/share/geosite/loyalsoldier.dat GeoSite.dat
	ln -s /usr/share/geoip/loyalsoldier.dat GeoIP.dat
	mihomo -d . -t || die

	insinto /etc/mihomo
	doins config.yaml
	dosym /usr/share/geosite/loyalsoldier.dat /etc/mihomo/GeoSite.dat
	dosym /usr/share/geoip/loyalsoldier.dat /etc/mihomo/GeoIP.dat
}

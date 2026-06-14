EAPI="8"
DESCRIPTION="dnsmasq profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPEND="dev-lang/python"
RDEPEND="net-dns/dnsmasq"
S="${T}"

src_install() {
  insinto /etc
  escript gen-network.py dnsmasq .
  doins dnsmasq.conf

  systemd_enable_service multi-user.target dnsmasq.service

  # presets:
  echo "enable dnsmasq.service" > "${T}/02-dnsmasq.preset"
  insinto "$(systemd_get_systempresetdir)"
  doins "${T}/02-dnsmasq.preset"
}

pkg_preinst() {
  if grep -q "Configuration file for dnsmasq" /etc/dnsmasq.conf; then
    rm -v /etc/dnsmasq.conf
  fi
}

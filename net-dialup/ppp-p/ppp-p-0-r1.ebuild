EAPI="8"
DESCRIPTION="ppp profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPEND="dev-lang/python"
RDEPEND="net-dialup/ppp"
S="${T}"

src_install() {
  insinto /etc/ppp/peers
  escript gen-network.py pppoe pppoe
  doins pppoe/*

  insinto "$(systemd_get_systemunitdir)"
  doins "${FILESDIR}/pppd@.service"

  for peer in pppoe/*; do
    peer="$(basename "${peer}")"
    systemd_enable_service_template multi-user.target "pppd@${peer}.service" "pppd@.service"

    # presets:
    echo "enable pppd@${peer}.service" >> "${T}/01-pppd.preset"
  done
  insinto "$(systemd_get_systempresetdir)"
  doins "${T}/01-pppd.preset"
}

EAPI="8"
DESCRIPTION="nftables profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPENDS="dev-lang/python"
RDENEPDS="net-firewall/nftables"
S="${T}"

src_install() {
  # try preventing mis-store:
  insopt --mode 0444
  insinto /var/lib/nftables
  echo 'include "/etc/nftables.rules.d/*.rules"' > "${T}/rules-save"
  doins "${T}/rules-save"
  insopt

  insinto /etc/nftables.rules.d/
  escript gen-network.py nftables nftables
  doins nftables/*

  # only load, don't store:
  systemd_enable_service multi-user.target nftables-load.service

  # presets:
  {
    echo "disable nftables-store.service"
    echo "enable nftables-load.service"
  } > "${T}/03-nftables.preset"
  insinto "$(systemd_get_systempresetdir)"
  doins "${T}/03-nftables.preset"
}

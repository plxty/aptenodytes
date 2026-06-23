EAPI="8"
DESCRIPTION="nftables profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPEND="dev-lang/python"
RDEPEND="net-firewall/nftables"
S="${T}"

src_install() {
	# try preventing mis-store, and for #691326 should set the perms:
	insopts --mode 0400
	insinto /var/lib/nftables
	echo 'include "/etc/nftables.rules.d/*.rules"' >"${T}/rules-save"
	doins "${T}/rules-save"

	insinto /etc/nftables.rules.d/
	escript gen-network.py nftables nftables
	for rule in nftables/*; do
		nft -cf "${rule}" || die "Invalid syntax for nftable rules: ${rule}"
		doins "${rule}"
	done
	insopts

	# only load, don't store:
	systemd_enable_service multi-user.target nftables-load.service

	# presets:
	{
		echo "disable nftables-store.service"
		echo "enable nftables-load.service"
	} >"${T}/03-nftables.preset"
	insinto "$(systemd_get_systempresetdir)"
	doins "${T}/03-nftables.preset"
}

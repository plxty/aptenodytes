EAPI="8"
DESCRIPTION="nftables profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds systemd

BDEPEND="dev-lang/python"
RDEPEND="net-firewall/nftables"
S="${T}"

# TODO: refactor all other -p ebuilds...
src_prepare() {
	default

	echo 'include "/etc/nftables.rules.d/*.rules"' >rules-save
	escript gen-network.py nftables nftables

	# only load, don't store:
	{
		echo "disable nftables-store.service"
		echo "enable nftables-load.service"
	} >03-nftables.preset
}

src_install() {
	# try preventing mis-store, and for #691326 should set the perms:
	insopts --mode 0400
	insinto /var/lib/nftables
	doins "${T}/rules-save"

	# here because: netlink: Error: cache initialization failed don't cache
	for rule in nftables/*; do
		nft -cf "${rule}" || die "Invalid syntax for nftable rules: ${rule}"
	done

	insinto /etc/nftables.rules.d/
	doins nftables/*
	insopts

	# presets:
	insinto "$(systemd_get_systempresetdir)"
	doins 03-nftables.preset

	systemd_enable_service multi-user.target nftables-load.service
}

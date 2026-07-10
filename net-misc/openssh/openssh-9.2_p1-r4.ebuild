EAPI="8"

inherit dirty-deeds systemd
eval "$(pkg_profile)"

KEYWORDS="amd64"
IUSE="server"
RDEPEND+=" !net-misc/openssh-p"
S="${T}"

src_prepare() {
	default

	echo "enable sshd.service" >00-sshd.preset
}

src_install() {
	# firewall? port?
	systemd_enable_service multi-user.target sshd.service

	# presets:
	insinto "$(systemd_get_systempresetdir)"
	doins 00-sshd.preset
}

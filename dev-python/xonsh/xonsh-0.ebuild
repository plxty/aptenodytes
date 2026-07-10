EAPI="8"

inherit dirty-deeds
eval "$(pkg_profile)"

KEYWORDS="amd64 arm64-macos"
IUSE="iglu_lives_byte"
RDEPEND+=" iglu_lives_byte? ( acct-user/byte )"
S="${T}"

src_install() {
	# TODO: rc.d? @see XONSHRC_DIR
	userinsinto .config/xonsh
	userdoins "${FILESDIR}/rc.xsh"
}

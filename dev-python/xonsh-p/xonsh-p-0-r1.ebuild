EAPI="8"
DESCRIPTION="xonsh profile"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

inherit dirty-deeds

IUSE="iglu_lives_byte"
RDEPEND="
  dev-python/xonsh
  iglu_lives_byte? ( acct-user/byte )
"
S="${T}"

src_install() {
	# TODO: rc.d? @see XONSHRC_DIR
	userinsinto .config/xonsh
	userdoins "${FILESDIR}/rc.xsh"
}

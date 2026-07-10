EAPI="8"

SLOT="ridgeni"
DESCRIPTION="${CATEGORY}/${PN}:${SLOT}"
KEYWORDS="amd64 arm64-macos"

inherit dirty-deeds

IUSE="iglu_lives_byte"
RDEPEND="
	dev-python/xonsh:0
	iglu_lives_byte? ( acct-user/byte )
"
S="${T}"

src_install() {
	# TODO: rc.d? @see XONSHRC_DIR
	userinsinto .config/xonsh
	userdoins "${FILESDIR}/rc.xsh"
}

EAPI="8"

PYTHON_COMPAT=(python3_{13..14})
inherit dirty-deeds python-r1
eval "$(pkg_profile)"

KEYWORDS="amd64 arm64-macos"
IUSE="iglu_lives_byte"
RDEPEND+="
	!dev-python/xonsh-p
	iglu_lives_byte? ( acct-user/byte )
	dev-python/xontrib-fzf-completions[${PYTHON_USEDEP}]
"
S="${T}"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

src_install() {
	# TODO: rc.d? @see XONSHRC_DIR
	userinsinto .config/xonsh
	userdoins "${FILESDIR}/rc.xsh"
}

EAPI="8"

# this is a profile with different slot :)
SLOT="ridgeni"
DESCRIPTION="${CATEGORY}/${PN}:${SLOT}"
KEYWORDS="amd64 arm64-macos"

inherit dirty-deeds

# note for original helix we still need a slot :0...
IUSE="iglu_lives_byte"
RDEPEND="
	app-editors/helix:0
	iglu_lives_byte? ( acct-user/byte )
	dev-util/ruff
	dev-util/ty
	dev-util/bash-language-server
	dev-util/shellcheck-bin
"
case "${CHOST}" in
*"-linux"*)
	RDEPEND+="llvm-core/clang"
	;;
	# darwin has a builtin clangd, we now use it instead...
esac
S="${T}"

src_install() {
	userinsinto .config/helix
	userdoins "${FILESDIR}/"{config.toml,languages.toml}
}

pkg_postinst() {
	# ${EPREFIX}/etc/env.d/99editor
	eselect editor set hx
}

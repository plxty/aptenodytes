EAPI="8"

# this is a profile with different slot :)
inherit dirty-deeds
eval "$(pkg_profile)"

KEYWORDS="amd64 arm64-macos"
IUSE="iglu_lives_byte"

# dev-util/ty is quite un-maintained, using a more stable one...
RDEPEND+="
	!app-editors/helix-p
	iglu_lives_byte? ( acct-user/byte )
	dev-util/ruff
	dev-python/python-lsp-server
	dev-util/bash-language-server
	dev-util/shellcheck-bin
"
case "${CHOST}" in
*"-linux"*)
	RDEPEND+=" llvm-core/clang"
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

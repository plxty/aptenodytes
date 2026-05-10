EAPI="8"
DESCRIPTION="helix profile"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

inherit dirty-deeds

IUSE="iglu_lives_byte"
RDEPEND="
  app-editors/helix
  iglu_lives_byte? ( acct-user/byte )
  dev-util/ty
  dev-util/bash-language-server
  dev-util/shellcheck-bin
"
case "${CHOST}" in
  *"-linux"*)
    RDEPEND+="llvm-core/clang" ;;
  # darwin has a builtin clangd, we now use it instead...
esac
S="${T}"

src_install() {
  userinsinto .config/helix
  userdoins "${FILESDIR}/"{config.toml,languages.toml}
}

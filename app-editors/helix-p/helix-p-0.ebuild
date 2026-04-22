EAPI="8"
DESCRIPTION="helix profile"
KEYWORDS="amd64"
SLOT="0"

inherit dirty-deeds

IUSE="iglu_lives_byte"
RDEPEND="
  app-editors/helix
  iglu_lives_byte? ( acct-user/byte )
  llvm-core/clang
  dev-util/bash-language-server
  dev-util/ty
"
S="${T}"

src_install() {
  userinsinto .config/helix
  userdoins "${FILESDIR}/"{config.toml,languages.toml}
}

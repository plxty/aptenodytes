EAPI="8"
DESCRIPTION="helix profile"
KEYWORDS="amd64 arm64-macos"
SLOT="0"

inherit dirty-deeds

# fixing rdepends...
#   llvm-core/clang
#   dev-util/bash-language-server
#   dev-util/ty

IUSE="iglu_lives_byte"
RDEPEND="
  app-editors/helix
  iglu_lives_byte? ( acct-user/byte )
"
S="${T}"

src_install() {
  userinsinto .config/helix
  userdoins "${FILESDIR}/"{config.toml,languages.toml}
}

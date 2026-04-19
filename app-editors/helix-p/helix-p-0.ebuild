EAPI="9"
KEYWORDS="amd64"
IUSE="iglu_lives_byte"
RDEPEND="
  app-editors/helix
  iglu_lives_byte? ( acct-user/byte )
"

# plus development tools:
RDEPEND+="
  llvm-core/clang
  dev-util/bash-language-server
  dev-util/ty
"

DESCRIPTION="helix profile"
SLOT="0"

S="${T}"

src_install() {
  # eclass?
  for flag in $USE; do
    user="${flag#iglu_lives_}"
    if [[ "${user}" == "" ]]; then
      continue
    fi
    insinto "$(getent passwd "${user}" | cut -d: -f6)/.config/helix"
    insopts --owner "${user}" --group "${user}"
    doins "${FILESDIR}/"{config.toml,languages.toml}
  done
}

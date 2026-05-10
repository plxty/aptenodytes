EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

KEYWORDS="${KEYWORDS} ~arm64-macos"
SRC_URI+="
  arm64-macos? ( https://github.com/koalaman/shellcheck/releases/download/v${PV}/${SC_P}.darwin.aarch64.tar.xz )
"

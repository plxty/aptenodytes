EAPI="8"

inherit dirty-deeds
pkg_overlay

if [[ "${CHOST}" == *"-darwin"* ]]; then
  KEYWORDS="${KEYWORDS} arm64-macos"
  SHELLCHECK_BASEURL="https://github.com/koalaman/shellcheck/releases/download/v${PV}/${SC_P}.darwin."
  SRC_URI="arm64-macos? ( ${SHELLCHECK_BASEURL}aarch64.tar.xz )"
fi

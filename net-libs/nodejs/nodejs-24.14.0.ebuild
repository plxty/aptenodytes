EAPI="8"

inherit dirty-deeds
pkg_overlay

if [[ "${ARCH}" == "arm64-macos" ]]; then
  KEYWORDS="${KEYWORDS} ~arm64-macos"
  PATCHES+=("${FILESDIR}/nodejs-24.14.0-darwin.patch")
fi

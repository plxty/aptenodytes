EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  KEYWORDS="${KEYWORDS} ~arm64-macos"
  PATCHES+=("${FILESDIR}/${P}-darwin.patch")
fi

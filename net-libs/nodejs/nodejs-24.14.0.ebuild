EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay --arch arm64-macos)"

PATCHES+=("${FILESDIR}/${P}-darwin.patch")

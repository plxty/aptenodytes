EAPI="8"

inherit dirty-deeds
eval "$(pkg_override --arch arm64-macos)"

PATCHES+=("${FILESDIR}/${P}-darwin.patch")

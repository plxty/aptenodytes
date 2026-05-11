EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

# https://github.com/boostorg/context/commit/fda3986b10926fa94103abca0190cd063f14544c.patch
PATCHES+=("${FILESDIR}/${P}-context-build.patch")

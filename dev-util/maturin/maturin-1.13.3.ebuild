EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

# https://devmanual.gentoo.org/general-concepts/mirrors/index.html#restricting-automatic-mirroring
RESTRICT="primaryuri"

# original vendor seems lacking support for macOS, we put it up:
SRC_URI+="
  https://github.com/plxty/aptenodytes/releases/download/dist/${P}-vendor.tar.xz
"
KEYWORDS="${KEYWORDS} ~arm64-macos"

# patch if we're mac:
if [[ "${ARCH}" == *"-macos" ]]; then
  PATCHES+=("${FILESDIR}/${PN}-workaround-mach-o-rpath.patch")
fi

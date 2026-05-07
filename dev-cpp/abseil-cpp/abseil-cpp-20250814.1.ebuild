EAPI="8"

inherit dirty-deeds
pkg_overlay

if [[ "${ARCH}" == "arm64-macos" ]]; then
  PATCHES+=("${FILESDIR}/${PN}-darwin-gcc-15.patch")
fi

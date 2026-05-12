EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

# owning features:
KEYWORDS="${KEYWORDS} ~arm64-macos"
PATCHES+=("${FILESDIR}/${PN}-temp-ascii.patch")

if suse prefix; then
  eval __"$(declare -f cmake_src_configure)"
  cmake_src_configure() {
    # for darwin. it searches SDK's marisa, instead of gentoo, so correct it:
    mycmakeargs+=("-DMarisa_ROOT=${EPREFIX}")
    __cmake_src_configure "${@}"
  }
fi

EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  # upstream has no any keywords available, wait for stable...
  # KEYWORDS="${KEYWORDS} ~arm64-macos"

  # https://github.com/libevent/libevent/issues/920#issuecomment-546596875
  PATCHES+=("${FILESDIR}/${P}-osx-rpath.patch")
fi

EAPI="7"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
  PATCHES+=("${FILESDIR}/${P}-libctf-weak-symbols.patch")
fi

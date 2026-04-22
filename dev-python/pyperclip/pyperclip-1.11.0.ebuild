EAPI="8"

inherit dirty-deeds
pkg_overlay

if scopeuse prefix-guest; then
  # don't pull in x11 dependencies to here
  RDEPEND=""
  KEYWORDS="${KEYWORDS} arm64-macos"

  # avoid using FILESDIR, we can't handle it
  eval "$(declare -f src_prepare | sed 's/PATCHES/PATCHES_DISABLED/')"
fi

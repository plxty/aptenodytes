EAPI="8"

inherit dirty-deeds
pkg_overlay

if scopeuse prefix-guest; then
  PATCHES+=("${FILESDIR}/${PN}-repo-aliases.patch")
fi

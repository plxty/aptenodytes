EAPI="8"

inherit dirty-deeds
pkg_overlay

if suse prefix-guest; then
  PATCHES+=("${FILESDIR}/${PN}-repo-aliases.patch")
fi

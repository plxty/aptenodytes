EAPI="8"

inherit dirty-deeds
eval "$(pkg_override)"

if guse prefix-guest; then
	PATCHES+=("${FILESDIR}/${PN}-repo-aliases.patch")
fi

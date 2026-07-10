EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay --arch arm64-macos)"

# don't pull in x11 dependencies to here
RDEPEND=""

# avoid using FILESDIR, we don't want to handle it
src_prepare_text="$(declare -f src_prepare)"
eval "${src_prepare_text//PATCHES/_}"

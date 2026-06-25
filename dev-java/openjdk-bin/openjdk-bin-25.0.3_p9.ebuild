EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay --arch arm64-macos)"

# to avoid download too much files...
SRC_URI="$(abi_uri aarch64 arm64-macos)"

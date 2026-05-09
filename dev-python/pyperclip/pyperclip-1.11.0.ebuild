EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  # don't pull in x11 dependencies to here
  RDEPEND=""
  KEYWORDS="${KEYWORDS} ~arm64-macos"

  # avoid using FILESDIR, we can't handle it
  src_prepare_text="$(declare -f src_prepare)"
  eval "${src_prepare_text//PATCHES/_}"
fi

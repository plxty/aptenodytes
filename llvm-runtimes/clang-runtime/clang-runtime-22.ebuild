EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
  eval __"$(declare -f src_install)"
  src_install() {
    __src_install "${@}"

    for abi in $(get_all_abis); do
      # append the runtime directory actually, for -lclang_rt.osx to work:
      local abi_chost=$(get_abi_CHOST "${abi}")
      {
        echo "-Wl,-rpath,${EPREFIX}/usr/lib/clang/${SLOT}/lib/darwin"
        echo "-Wl,-L,${EPREFIX}/usr/lib/clang/${SLOT}/lib/darwin"
      } >> "${ED}/etc/clang/${SLOT}/gentoo-runtimes.cfg"

      # sync with @see clang-common
      for tool in clang{,++,-cpp}; do
        dosym "${abi_chost}-${tool}.cfg" "/etc/clang/${SLOT}/${abi_chost/darwin25/macosx}-${tool}.cfg"
      done
    done
  }
fi

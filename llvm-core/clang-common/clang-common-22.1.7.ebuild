EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

if [[ "${ARCH}" == *"-macos" ]]; then
  # FIXME: ways to avoid hardcoding the gcc version?
  RDEPEND="sys-devel/gcc:15"

  eval __"$(declare -f src_install)"
  src_install() {
    __src_install "${@}"

    # workaround to use system compiler-rt in darwin, instead of libgcc:
    # @see clang-rtlib-config
    sed -i 's/libgcc/platform/g' "${ED}/etc/clang/gentoo-runtimes.cfg"

    for abi in $(get_all_abis); do
      local abi_chost=$(get_abi_CHOST "${abi}")
      {
        # gentoo-gcc-install.cfg should takes care?
        echo "-Wl,-rpath,${EPREFIX}/usr/lib/gcc/${abi_chost}/15"
        echo "-Wl,-L,${EPREFIX}/usr/lib/gcc/${abi_chost}/15"
      } >> "${ED}/etc/clang/gentoo-common.cfg"

      # symlink a macosx one, trick cc-rs/src/target/generated.rs:
      # @see clang-runtime
      for tool in clang{,++,-cpp}; do
        dosym "${abi_chost}-${tool}.cfg" "/etc/clang/${abi_chost/darwin25/macosx}-${tool}.cfg"
      done
    done
  }
fi

EAPI="8"

inherit dirty-deeds
pkg_overlay

if scopeuse prefix-guest; then
  eval __"$(declare -f src_install)"
  src_install() {
    # replacing the install_name of all grammars
    if use grammar; then
      for lib in runtime/grammars/*.so; do
        install_name_tool -id "${EPREFIX}/usr/$(get_libdir)/${PN}/$(basename "${lib}")" "${lib}"
      done
    fi
    __src_install
  }
fi

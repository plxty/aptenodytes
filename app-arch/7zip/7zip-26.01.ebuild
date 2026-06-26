EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay --arch arm64-macos)"

# avoid -z linker flag, unsupported
src_compile_text="$(declare -f src_compile)"
eval "${src_compile_text/append-ldflags -Wl,-z,noexecstack/:}"

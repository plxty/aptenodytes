EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay --repo guru)"

if [[ "${ARCH}" == "arm64-macos" ]]; then
  KEYWORDS="${KEYWORDS} ~arm64-macos"
  # try without dbus, currently broken on gcc 15:
  DEPEND="${DEPEND/sys-apps\/dbus/}"
  RDEPEND="${DEPEND}"

  SRC_URI+="
    arm64-macos? (
      https://github.com/denoland/rusty_v8/releases/download/v${RUSTY_V8_TAG}/librusty_v8_release_aarch64-apple-darwin.a.gz
        -> rusty_v8_${RUSTY_V8_TAG}_librusty_v8_release_aarch64-apple-darwin.a.gz
      https://github.com/denoland/rusty_v8/releases/download/v${RUSTY_V8_TAG}/src_binding_release_aarch64-apple-darwin.rs
        -> rusty_v8_${RUSTY_V8_TAG}_src_binding_release_aarch64-apple-darwin.rs
    )
  "

  src_compile_text="$(declare -f src_compile)"
  # https://github.com/aws/aws-lc-rs/issues/1008#issuecomment-3774105038
  src_compile_text="${src_compile_text/cargo_src_compile/AWS_LC_SYS_NO_JITTER_ENTROPY="1" cargo_src_compile}"
  eval "${src_compile_text/local rusty_v8_triple/local rusty_v8_triple=aarch64-apple-darwin}"
fi

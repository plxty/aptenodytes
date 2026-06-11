# https://stackoverflow.com/a/32425874
eval __"$(declare -f die)"
die() {
  # make 05prefix (portage/bin/install-qa-check.d) don't die,
  # we're taking the real world (absolute!)
  if [[ "${1}" == "Aborting due to QA concerns: there are files installed outside the prefix" ]]; then
    return
  fi
  __die "${@}"
}

# Now macOS doesn't play very well with gcc due to private builtin and block...
# and the make.conf can't have a dynamic way to select what CC provides.
# To minimize the impact, just some uncompiled package listed here, aka package.env.
# @see portage myxfiles, the profile can't select per-package env...
case "${CATEGORY}/${PN}" in
  "dev-util/codex"|"dev-lang/python")
    # @see https://wiki.gentoo.org/wiki/LLVM/Clang
    export CC="${CHOST}-clang"
    export CPP="${CHOST}-clang-cpp"
    export CXX="${CHOST}-clang++"
    export AR="llvm-ar"
    export NM="llvm-nm"
    export RANLIB="llvm-ranlib" ;;
esac

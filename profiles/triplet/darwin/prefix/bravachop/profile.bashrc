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

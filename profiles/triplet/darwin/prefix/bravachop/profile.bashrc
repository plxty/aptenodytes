# @see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=78352
# @see https://gcc.gnu.org/bugzilla/show_bug.cgi?id=119435
# kind of package.env, @see portage myxfiles, profile can't have it...
case "${CATEGORY}/${PN}" in
	"dev-lang/python" | "dev-util/codex" | "dev-libs/leancrypto")
		# @see https://wiki.gentoo.org/wiki/LLVM/Clang
		export CC="${CHOST}-clang"
		export CPP="${CHOST}-clang-cpp"
		export CXX="${CHOST}-clang++"
		export AR="llvm-ar"
		export NM="llvm-nm"
		export RANLIB="llvm-ranlib"
		;;
esac

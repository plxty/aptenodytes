EAPI="8"
DESCRIPTION="xonsh shell"
KEYWORDS="amd64 ~arm64-macos"
SLOT="0"

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_13 )
inherit distutils-r1 pypi

# sources and patches
PATCHES=("${FILESDIR}/${P}-blink.patch")

# https://github.com/xonsh/xonsh/blob/main/pyproject.toml
RDEPEND="
  >=dev-python/prompt-toolkit-3.0.29[${PYTHON_USEDEP}]
  dev-python/pyperclip[${PYTHON_USEDEP}]
  >=dev-python/pygments-2.2[${PYTHON_USEDEP}]
  dev-python/ujson[${PYTHON_USEDEP}]
  dev-python/click[${PYTHON_USEDEP}]
"
case "${CHOST}" in
  *"-linux"*)
    RDEPEND+="dev-python/distro[${PYTHON_USEDEP}]" ;;
  # gnureadline is already a part of python in darwin
esac
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

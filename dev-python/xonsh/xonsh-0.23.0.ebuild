EAPI="8"
KEYWORDS="amd64"

DESCRIPTION="xonsh shell"
SLOT="0"

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_13 )
inherit distutils-r1 pypi

# https://github.com/xonsh/xonsh/blob/main/pyproject.toml
# missing: mac = ["gnureadline"]
RDEPEND="
  >=dev-python/prompt-toolkit-3.0.29[${PYTHON_USEDEP}]
  dev-python/pyperclip[${PYTHON_USEDEP}]
  >=dev-python/pygments-2.2[${PYTHON_USEDEP}]
  dev-python/distro[${PYTHON_USEDEP}]
  dev-python/ujson[${PYTHON_USEDEP}]
  dev-python/click[${PYTHON_USEDEP}]
"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

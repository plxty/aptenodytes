EAPI="8"
DESCRIPTION="fzf completions for xonsh"
KEYWORDS="amd64 ~arm64-macos"
SLOT="0"

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=(python3_{13..14})
inherit distutils-r1 pypi

RDEPEND="
	dev-python/xonsh[${PYTHON_USEDEP}]
	app-shells/fzf
"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

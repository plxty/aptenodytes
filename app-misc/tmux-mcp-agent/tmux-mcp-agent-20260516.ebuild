EAPI="8"
DESCRIPTION="Let AI Agents control your remote servers through tmux."
KEYWORDS="amd64 arm64-macos"
SLOT="0"

TMUX_MCP_AGENT_TAG="0359b8990649bb615f3feccfc0ccae7aaf7a0f86"
SRC_URI="https://github.com/quink-black/tmux-mcp-agent/archive/${TMUX_MCP_AGENT_TAG}.zip -> ${P}.zip"
LICENSE="MIT"
S="${WORKDIR}/${PN}-${TMUX_MCP_AGENT_TAG}"

DISTUTILS_USE_PEP517=setuptools
PYTHON_COMPAT=( python3_{13..14} )
inherit distutils-r1

RDEPEND="dev-python/mcp[${PYTHON_USEDEP}]"
REQUIRED_USE="${PYTHON_REQUIRED_USE}"

src_prepare() {
  default

  # make tmux agent a package:
  cat > pyproject.toml <<EOF || die
[build-system]
requires = ["setuptools"]
build-backend = "setuptools.build_meta"

[project]
name = "tmux_agent"
version = "${PV}"
requires-python = ">=3.13"

[tool.setuptools]
py-modules = ["tmux_agent"]
EOF

  # make mcp server a executable:
  mv mcp_server.py tmux-mcp
}

python_install() {
  distutils-r1_python_install
  exeinto "/usr/bin"
  doexe "tmux-mcp"
}

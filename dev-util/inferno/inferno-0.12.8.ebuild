EAPI="8"
DESCRIPTION="inferno flamegraph"
KEYWORDS="~amd64 ~arm64-macos"
SLOT="0"

LICENSE="CDDL"
LICENSE+=" Apache-2.0 BSD MIT Unicode-3.0 ZLIB"

RUST_MIN_VER="1.87.0"
inherit cargo

# [aptenodytes] make_bundle=vendor/inferno
SRC_URI="
	https://github.com/jonhoo/inferno/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
	https://github.com/plxty/aptenodytes/releases/download/dist/${P}-crates.tar.xz
"

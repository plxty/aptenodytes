EAPI="8"
DESCRIPTION="Larkoffice CLI"
KEYWORDS="~amd64 ~arm64-macos"
SLOT="0"

inherit go-module

SRC_URI="
  https://github.com/larksuite/cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
  https://github.com/plxty/aptenodytes/releases/download/dist/${P}-vendor.tar.xz
"
S="${WORKDIR}/cli-${PV}"

src_compile() {
  # TODO: avoid `scripts/fetch_meta.py` as it pulls down from internet.
  emake build
}

src_install() {
  dobin "${PN}"
}

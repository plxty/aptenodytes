EAPI="8"
DESCRIPTION="Larkoffice CLI"
KEYWORDS="~amd64 ~arm64-macos"
SLOT="0"

inherit go-module

# note: meta_data.json contains in vendor file to prevent from frequently csum:
SRC_URI="
  https://github.com/larksuite/cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
  https://github.com/plxty/aptenodytes/releases/download/dist/${P}-vendor.tar.xz
"

# note the vendor directory should also match the cli-xxx:
S="${WORKDIR}/cli-${PV}"

src_prepare() {
  default
  mv vendor/meta_data.json internal/registry
  sed -i "s/echo dev/echo v${PN}/g" Makefile
}

src_compile() {
  emake build
}

src_install() {
  dobin "${PN}"
}

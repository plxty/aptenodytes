EAPI="8"
DESCRIPTION="Larkoffice CLI"
KEYWORDS="~amd64 ~arm64-macos"
SLOT="0"

inherit go-module

# [aptenodytes] make_bundle=vendor/lark-cli
SRC_URI="
  https://github.com/larksuite/cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
  https://github.com/plxty/aptenodytes/releases/download/dist/${P}-vendor.tar.xz
"

# note the vendor directory should also match the cli-xxx:
S="${WORKDIR}/cli-${PV}"

src_prepare() {
	default
	sed -i "s/echo dev/echo v${PV}/g" Makefile
}

src_compile() {
	emake build
}

src_install() {
	dobin "${PN}"
}

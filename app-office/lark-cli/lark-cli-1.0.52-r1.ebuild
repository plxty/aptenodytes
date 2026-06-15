EAPI="8"
DESCRIPTION="Larkoffice CLI"
KEYWORDS=""
SLOT="0"

inherit go-module

# using revison for a new meta_data released...
SRC_URI="
  https://open.feishu.cn/api/tools/open/api_definition?protocol=meta&client_version=v${PV} -> meta_data.${PF}.json
  https://github.com/larksuite/cli/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz
  https://github.com/plxty/aptenodytes/releases/download/dist/${P}-vendor.tar.xz
"

# note the vendor directory should also match the cli-xxx:
S="${WORKDIR}/cli-${PV}"
BDEPEND="app-misc/jq"

src_prepare() {
  default
  jq ".data" < "${DISTDIR}/meta_data.${PF}.json" > internal/registry/meta_data.json
  sed -i "s/echo dev/echo v${PN}/g" Makefile
}

src_compile() {
  emake build
}

src_install() {
  dobin "${PN}"
}

EAPI=8
DESCRIPTION="opencode cli"
KEYWORDS="amd64 ~arm64-macos"
SLOT="0"

# https://github.com/microcai/gentoo-zh/blob/master/dev-util/opencode-bin/opencode-bin-1.14.22.ebuild
OPENCODE_BASEURL="https://github.com/anomalyco/opencode/releases/download/v${PV}/opencode-"
SRC_URI="
  amd64? ( ${OPENCODE_BASEURL}linux-x64.tar.gz -> ${P}-amd64.tar.gz )
  arm64-macos? ( ${OPENCODE_BASEURL}darwin-arm64.zip -> ${P}-arm64-macos.zip )
"
S="${WORKDIR}"
QA_PREBUILT="usr/bin/opencode"

src_install() {
  dobin opencode
}

EAPI="8"
DESCRIPTION="rime-ice profile"
KEYWORDS="arm64-macos"
SLOT="0"

AP="${P/-p/}"
APN="${PN/-p/}"
SRC_URI="https://github.com/iDvel/rime-ice/releases/download/${PV}/full.zip -> ${AP}.zip"
PATCHES=("${FILESDIR}/${APN}-double-pinyin-abc.patch")
S="${WORKDIR}"

inherit dirty-deeds

IUSE="iglu_lives_byte"
RDEPENDS="
  app-i18n/librime
  app-i18n/librime-lua
  iglu_lives_byte? ( acct-user/byte )
"

src_install() {
  # other platforms?
  userinsinto "Library/Rime"

  # rime_deployer?
  userdoins -r cn_dicts en_dicts lua opencc
  userdoins ./*.yaml ./*.txt
}

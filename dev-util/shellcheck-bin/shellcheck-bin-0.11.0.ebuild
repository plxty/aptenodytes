# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

SC_P=${PN%-bin}-v${PV}
SC_URI="https://github.com/koalaman/shellcheck/releases/download/v${PV}/${SC_P}"

DESCRIPTION="Shell script analysis tool (binary package)"
HOMEPAGE="https://www.shellcheck.net/"
SRC_URI="${SC_URI}.darwin.aarch64.tar.xz"
S=${WORKDIR}/${SC_P}

LICENSE="GPL-3+"
SLOT="0"
# to reduce SRC_URI mess with override's Manifest, we keep it minimal:
KEYWORDS="~arm64-macos"

RDEPEND="!dev-util/shellcheck"

QA_PREBUILT="usr/bin/shellcheck"

src_install() {
	dobin shellcheck
	einstalldocs
}

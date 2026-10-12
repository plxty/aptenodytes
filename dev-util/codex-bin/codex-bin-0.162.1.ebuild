# Copyright 2025-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="${PN%-bin}"
URI_PREFIX="https://github.com/openai/${MY_PN}/releases/download/rust-v${PV}"

DESCRIPTION="Codex CLI - OpenAI's AI-powered coding agent"
HOMEPAGE="https://github.com/openai/codex"
SRC_URI="
	arm64-macos? (
		${URI_PREFIX}/codex-package-aarch64-apple-darwin.tar.gz
			-> ${P}-arm64-macos.tar.gz
	)
"
S="${WORKDIR}"

LICENSE="
	Apache-2.0 Apache-2.0-with-LLVM-exceptions BSD-2 BSD Boost-1.0
	CC0-1.0 CDLA-Permissive-2.0 ISC LGPL-2+ MIT MPL-2.0 Unicode-3.0
	ZLIB ZSH
"
SLOT="0"

# [aptenodytes] accept_keywords=~amd64 repo_override=gentoo-zh
KEYWORDS="~arm64-macos"

RDEPEND="
	!dev-util/codex
	sys-libs/ncurses:0/6
"

RESTRICT="strip"
QA_PREBUILT="
	usr/libexec/${MY_PN}/bin/${MY_PN}
	usr/libexec/${MY_PN}/bin/${MY_PN}-code-mode-host
	usr/libexec/${MY_PN}/${MY_PN}-path/rg
	usr/libexec/${MY_PN}/${MY_PN}-resources/bwrap
	usr/libexec/${MY_PN}/${MY_PN}-resources/zsh/bin/zsh
"

src_install() {
	local install_dir="/usr/libexec/${MY_PN}"

	insinto "${install_dir}"
	doins -r bin "${MY_PN}-path" "${MY_PN}-resources"
	doins "${MY_PN}-package.json"

	fperms 0755 \
		"${install_dir}/bin/${MY_PN}" \
		"${install_dir}/bin/${MY_PN}-code-mode-host" \
		"${install_dir}/${MY_PN}-path/rg" \
		"${install_dir}/${MY_PN}-resources/bwrap" \
		"${install_dir}/${MY_PN}-resources/zsh/bin/zsh"

	dosym -r "${install_dir}/bin/${MY_PN}" "/usr/bin/${MY_PN}"
}

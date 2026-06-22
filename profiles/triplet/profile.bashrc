# check if pkg_overlay, but outdated that portage selects the original:
if [[ "${EBUILD_PHASE}" == "clean" ]]; then
  pkg_overlay="${EPREFIX}/var/db/repos/aptenodytes/${CATEGORY}/${PN}"
  if test -e "${pkg_overlay}"/*.ebuild && [[ ! -e "${pkg_overlay}/${PF}.ebuild" ]]; then
    # checks only hacked package by me :) focus on which compiles but unpatch:
    case "${CATEGORY}/${PN}" in
      "sys-kernel/gentoo-kernel"|"app-editors/helix"|"app-i18n/librime")
        die "Overlay package ${PF}::aptenodytes isn't selected" ;;
      "llvm-"*"/"*|"dev-libs/libiconv"|"dev-util/maturin")
        if [[ "${ARCH}" == *"-macos" ]]; then
          die "Overlay package ${PF}::aptenodyte isn't selected for macOS"
        fi ;;
    esac
  fi
fi

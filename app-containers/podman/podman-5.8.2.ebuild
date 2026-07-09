EAPI="8"

inherit dirty-deeds
eval "$(pkg_overlay)"

# only with prefix, we fix-up the wrong config location...
if guse prefix; then
  eval __"$(declare -f src_prepare)"
  src_prepare() {
    __src_prepare
    sed -i -e "s%/etc%${EPREFIX}/etc%g" \
      -e "s%/usr%${EPREFIX}/usr%g" \
      -e "s%/var%${EPREFIX}/var%g" \
      vendor/go.podman.io/common/pkg/config/config_linux.go \
      vendor/go.podman.io/storage/types/options_linux.go \
      vendor/go.podman.io/storage/storage.conf \
      vendor/go.podman.io/image/v5/signature/policy_paths_common.go \
      vendor/go.podman.io/image/v5/pkg/sysregistriesv2/paths_common.go \
      vendor/go.podman.io/image/v5/docker/paths_common.go \
      vendor/go.podman.io/image/v5/docker/registries_d.go || die
  }
fi

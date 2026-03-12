{
  lib,
  fetchFromGitHub,
  pkgsStatic,
  python3Packages,
  runCommand,
  writers,
  patchutils,
  qemu_kvm,
  virtiofsd,
  busybox,
  ...
}:

# https://github.com/zyklotomic/virtme-ng-flake.nix/blob/master/flake.nix

let
  version = "1.40";
  src = fetchFromGitHub {
    owner = "arighi";
    repo = "virtme-ng";
    rev = "v${version}";
    sha256 = "0zqyv3s2xr4c934iin6jah6c311snllimi2cnjbp5lc0431pxwp6";
  };

  busybox-only = runCommand "busybox-only" { } ''
    mkdir -p "$out/bin"
    cp ${busybox}/bin/busybox "$out/bin/"
  '';

  # MUST static for --root to work:
  virtme-ng-init = pkgsStatic.rustPlatform.buildRustPackage rec {
    pname = "virtme-ng-init";
    inherit src version;
    sourceRoot = "${src.name}/${lib.replaceStrings [ "-" ] [ "_" ] pname}";
    cargoHash = "sha256-3+MDf6pescqPnsQBOODZJ7ic2tqxh5LPvHIMouUkhjI=";

    # @see patchPhase, patchFlags
    depsBuildBuild = [ patchutils ];

    # Includes other things, to compatible with really "bare" environment, e.g. docker.
    # https://github.com/NixOS/nix/blob/324bfd82dca67c3189b0d218160da30a5e9b7637/docker.nix#L377
    # We include everything that equals when boot up, remains are let to direnv.
    patchPhase = ''
      runHook prePatch
      filterdiff -i '*/virtme_ng_init/*' ${./patches/virtme-ng-taste.patch} | patch -d.. -p1
      runHook postPatch
    '';
    preConfigure = ''
      echo -n "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:" > src/nix-path
      echo -n "${lib.makeBinPath [ busybox-only ]}" >> src/nix-path
    '';
  };
in
python3Packages.buildPythonPackage {
  pname = "virtme-ng";
  inherit src version;

  # @see doc/languages-frameworks/python.section.md
  pyproject = true;

  patches = [ ./patches/virtme-ng-taste.patch ];
  configurePhase = ''
    export BUILD_VIRTME_NG_INIT=1
    cp -r "${virtme-ng-init}/bin/." virtme/guest/bin/
  '';
  # We patch it ourselves, to ensure --root runs scripts properly without /nix
  dontPatchShebangs = true;

  # Legacy needs:
  build-system = with python3Packages; [
    argparse-manpage
    setuptools
  ];
  propagatedBuildInputs = with python3Packages; [
    argcomplete
    requests
  ];

  # Fake cargo and strip, we have already built ourselves.
  nativeBuildInputs = [
    (writers.writeBashBin "cargo" "echo SKIP CARGO")
    (writers.writeBashBin "strip" "echo SKIP STRIP")
  ];

  dependencies =
    (lib.map (
      n:
      writers.writeBashBin n ''
        # prefer security wrapped qemu (for rootless tun):
        if [[ -x "/run/wrappers/bin/${n}" ]]; then
          exec "/run/wrappers/bin/${n}" "$@"
        else
          exec "${qemu_kvm}/bin/${n}" "$@"
        fi
      ''
    ) [ "qemu-system-x86_64" ])
    ++ [ virtiofsd ];

  meta = {
    homepage = "https://github.com/arighi/virtme-ng";
    license = with lib.licenses; [ gpl2 ];
  };
}

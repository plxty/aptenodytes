{
  lib,
  n9 ? import ../lib { inherit lib; },
  fetchFromGitHub,
  mihomo,
  ...
}:

let
  version = "1.19.21";
  src = fetchFromGitHub {
    owner = "MetaCubeX";
    repo = "mihomo";
    tag = "v${version}";
    sha256 = "sha256-vNWnGLVbwsyD0DqOXe1dfUy/Mym+YhBzGlrZrgZ3RuE=";
  };
in
# buildGo, @see golangModuleVersion in nixpkgs-update:
n9.assureVersion mihomo version {
  inherit src;
  vendorHash = "sha256-yj+vCpwyyyw0++V1UHxzV8j1tZ+Jc65eilyef9UShZQ=";
}

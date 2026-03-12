{
  lib,
  n9 ? import ../lib { inherit lib; },
  fetchurl,
  flashspace,
  unzip,
  ...
}:

let
  version = "4.16.74";
  src = fetchurl {
    url = "https://github.com/wojciech-kulik/FlashSpace/releases/download/v${version}/FlashSpace.app.zip";
    sha256 = "sha256-2dUCTXa9JiuFP9CGDLseiXIqkqF1KqcWuS20rVwq4SQ=";
  };
in
n9.assureVersion flashspace version {
  inherit src;
  nativeBuildInputs = [ unzip ];
  unpackPhase = "unzip $src";
  sourceRoot = "flashspace.app";
}

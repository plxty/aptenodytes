{
  fetchFromGitHub,
  python3Packages,
  automake,
  autoconf,
  libtool,
  gnumake,
  pkg-config,
  elfutils,
  libdwarf,
  libkdumpfile,
  xz,
  ...
}:

python3Packages.buildPythonPackage rec {
  pname = "drgn";
  version = "0.1.0";
  src = fetchFromGitHub {
    owner = "osandov";
    repo = "drgn";
    tag = "v${version}";
    sha256 = "sha256-9foYSPwxneTqlckWFpi7Cge9ua4mpafhLkDYJE2ThiU=";
  };
  pyproject = true;

  # Legacy needs:
  build-system = with python3Packages; [
    setuptools
  ];

  # TODO: Something to nativeBuildInputs?
  depsBuildBuild = [
    automake
    autoconf
    libtool
    gnumake
  ];

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    elfutils
    libdwarf
    libkdumpfile
    xz
  ];
}

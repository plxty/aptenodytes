{
  description = "Aptenodytes declarative configuration on a native Gentoo environment";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/08d3a97586f6b6343b3b5e799980773629432610";
    home-manager = {
      url = "github:nix-community/home-manager/24f2190587513b9c2f73db112a17844ae912d965";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { self, nixpkgs, home-manager }: let
    api = import ./nix/lib { inherit nixpkgs; homeManager = home-manager; };
    system = "x86_64-linux";
    # Update this identity when changing the external build-tool environment.
    pkgs = api.mkPkgs { inherit system; toolchainId = "native-host-v1"; };
    systemExample = api.mkSystem { inherit pkgs; modules = [ ./nix/examples/evil.nix ]; };
    homeExample = api.mkHome { inherit pkgs; modules = [ ./nix/examples/home.nix ]; };
    environment = pkgs.buildEnv {
      name = "pseudo-env-example";
      paths = [
        (pkgs.writeTextDir "etc/generated" "retained\n")
        { isNative = true; nativeFiles."bin/not-installed" = "/native-missing/bin/tool"; }
      ];
    };
    evaluationChecks = import ./tests/config/evaluation.nix { inherit api pkgs; };
  in {
    lib = api;
    packages.${system} = {
      default = systemExample.artifact;
      system-example = systemExample.artifact;
      home-example = homeExample.artifact;
      pseudo-env-example = environment;
    };
    checks.${system} = {
      evaluation =
        assert builtins.all (passed: passed) (builtins.attrValues evaluationChecks);
        pkgs.writeText "aptenodytes-evaluation-checks" (builtins.toJSON evaluationChecks);
      config = pkgs.runCommand "aptenodytes-config-check" { } ''
        /usr/bin/python3 ${./tests/config/integration.py} \
          --repo ${./.} --system ${systemExample.artifact} \
          --home ${homeExample.artifact} --environment ${environment}
        mkdir -p "$out"
      '';
    };
  };
}

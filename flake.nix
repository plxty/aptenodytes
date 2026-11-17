{
  description = "Native Gentoo configuration artifacts for aptenodytes ridgeni profiles";

  # Only module sources and pure libraries are consumed, never the package set.
  inputs.nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?rev=33693d87d79fb2fa9c3c850e96f04b57f462af09";

  outputs = { nixpkgs, ... }:
    let
      api = import ./scripts/lib { inherit nixpkgs; };
      system = "x86_64-linux";
      pkgs = api.mkPkgs {
        inherit system;
        # Bump when changing the external host tools/libraries. The lock pins
        # module sources, not the Gentoo environment used by native builders.
        toolchainId = "gentoo-native-v1";
      };
      example = api.mkSystem {
        inherit pkgs;
        modules = [ ./scripts/examples/pppd.nix ];
      };
      evaluation = import ./scripts/tests/evaluation.nix { inherit api pkgs; };
    in
    {
      lib = api;
      packages.${system} = {
        default = example.artifact;
        pppd-example = example.artifact;
      };
      checks.${system} = {
        native-builders = import ./scripts/tests/builders.nix { inherit api pkgs; };
        evaluation =
          assert builtins.all (passed: passed) (builtins.attrValues evaluation);
          pkgs.writeText "aptenodytes-evaluation-checks" (builtins.toJSON evaluation);
        pppd = pkgs.runCommand "aptenodytes-pppd-check" { } ''
          /usr/bin/python3 ${./scripts/tests/integration.py} \
            --repo ${./.} --artifact ${example.artifact}
          mkdir -p "$out"
        '';
      };
    };
}

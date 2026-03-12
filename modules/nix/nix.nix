{
  config,
  lib,
  n9,
  pkgs,
  inputs,
  ...
}:

let
  inherit ((import ../../flake.nix).nixConfig) substituters;
in
{
  options.users = n9.mkAttrsOfSubmoduleOption { } {
    config.deployment.file.".local/share/nix/trusted-settings.json" = {
      text = ''
        {
          "substituters": { "${lib.concatStringsSep " " substituters}": true }
        }
      '';
      force = true;
    };
  };

  config.variant = lib.mkMerge [
    (lib.genAttrs [ "nixos" "nix-darwin" "home-manager" ] (_: {
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        # No duplicated entries, we control it all by hand :)
        substituters = lib.mkForce substituters;
      };

      nix.extraOptions = ''
        keep-outputs = true
        keep-derivations = true
      '';

      # To avoid deploying frequently:
      nix.registry = {
        # nix develop n9#qemu
        n9.to = {
          type = "path";
          path = config.deployment.rootAbsolute;
        };
      };

      # Inherited from @see nixpkgs.flake.setNixPath
      # If you want to `nix-shell`, using `nix-shell -p '(import <n9> args).pname'`
      nix.nixPath = [
        "n9=${config.deployment.rootAbsolute}"
        "nixpkgs=flake:nixpkgs"
      ];

      # https://nixos.wiki/wiki/Storage_optimization
      nix.gc = {
        automatic = true;
        options = "--delete-older-than 29d";
      };
    }))

    rec {
      nixos.nix.optimise.automatic = true;
      nix-darwin = nixos;
    }

    {
      nixos.nix.gc = {
        dates = "weekly";
        randomizedDelaySec = "3h";
      };
      home-manager.nix.package = pkgs.nix;
    }
  ];
}

{ lib, ... }: {
  # The upstream module exports ABI-specific variables for Nix's patched glibc.
  # Native applications use the host's locale configuration instead.
  disabledModules = [ "config/i18n.nix" ];
  # Do not install/update a second MIME database or man implementation by default.
  xdg.mime.enable = lib.mkDefault false;
  programs.man.enable = lib.mkDefault false;
  systemd.user.systemctlPath = lib.mkDefault "/usr/bin/systemctl";
}

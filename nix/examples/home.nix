{ pkgs, ... }: {
  home = {
    username = "example";
    homeDirectory = "/home/example";
    stateVersion = "26.05";
    sessionVariables.APTENODYTES_EXAMPLE = "native";
  };
  manual = { html.enable = false; json.enable = false; manpages.enable = false; };
  programs.man.enable = false;
  programs.git = {
    enable = true;
    package = pkgs.git;
    settings.init.defaultBranch = "main";
  };
  xdg.enable = true;
  xdg.configFile."aptenodytes/example.yaml".source = (pkgs.formats.yaml { }).generate "example.yaml" {
    command = "${pkgs.git}/bin/git";
    enabled = true;
    values = [ "yes" 2 null ];
  };
  systemd.user = {
    systemctlPath = "/usr/bin/systemctl";
    startServices = false;
    services.native-example = {
      Unit.Description = "Native Git configuration example";
      Service = { Type = "oneshot"; ExecStart = "${pkgs.git}/bin/git --version"; };
      Install.WantedBy = [ "default.target" ];
    };
  };
}

{
  n9.nixos.evil =
    { lib, pkgs, ... }:
    {
      hardware.configuration = ./hardware-configuration.nix;
      hardware.disk."disk/by-id/nvme-eui.002538b231b633a2".type = "zfs";
      programs.ssh.server.enable = true;

      networking = {
        bridge.br-lan = {
          # From left to right:
          slaves = [ "enp87s0" ];
        };

        router = {
          lan.br-lan = {
            address = "10.172.42.1/24";
            range = {
              from = "10.172.42.100";
              to = "10.172.42.254";
              mask = "255.255.255.0";
            };
          };
          wan.enp88s0 = { };
        };

        # Magic:
        clash.enable = true;
      };

      variant.nixos = {
        services.iperf3 = {
          enable = true;
          bind = "10.172.42.1";
        };

        # give qemu a cap_net_admin, @see nixpkgs/nixos/modules/programs/iotop.nix
        security.wrappers = lib.genAttrs [ "qemu-system-x86_64" ] (n: {
          owner = "root";
          group = "root";
          capabilities = "cap_net_admin+p";
          source = "${pkgs.qemu_kvm}/bin/${n}";
        });

        # Auto mounting the removable disk:
        # @see https://knazarov.com/posts/automount_usb_drives_in_nixos/
        services.udev.extraRules = lib.concatStrings [
          ''ACTION=="add", SUBSYSTEMS=="usb", SUBSYSTEM=="block", ''
          ''ENV{ID_FS_USAGE}=="filesystem", ENV{ID_SERIAL}=="ASMT_ASM246X_AAAABBBB0105-0:0", ''
          ''RUN{program}+="${pkgs.systemd}/bin/systemd-mount --no-block --collect $devnode /mnt/portal"''
        ];
      };

      users.byte = {
        environment.packages = with pkgs; [
          # cli
          git-repo
          pciutils
          bridge-utils
          minicom
          openocd
          btrfs-progs
        ];

        programs.code-server.enable = true;

        # Matched reject by default:
        variant.home-manager.programs.fish.functions.eject = ''
          if test (count $argv) -eq 0
            sudo eject -s -v /mnt/portal
          else
            sudo eject $argv
          end
        '';

        security.ssh-key = {
          private = "id_ed25519";
          public = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF7yxhz7Xm1rz0/3MkEwLKnIIACjVWFc9GLxwcxhtUy9 byte@evil";
          # agents = [ "byte@subsys" ]; # TODO: put to subsys?
        };

        # FIXME: Add modules/graphics/desktop.nix?
        variant.home-manager.services = {
          ssh-agent.enable = lib.mkForce false;
          gnome-keyring.enable = true;
        };
      };
    };
}

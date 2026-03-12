{ n9, pkgs, ... }:

let
  plugin = pkg: { inherit (pkg) name src; };
in
{
  options.users = n9.mkAttrsOfSubmoduleOption { } {
    config.variant.home-manager.programs.fish = {
      enable = true;

      plugins = with pkgs.fishPlugins; [
        (plugin fzf-fish)
        (plugin tide)
        (plugin puffer)
        {
          name = "upto";
          src = n9.sources.upto;
        }
      ];

      functions = {
        # https://github.com/kpbaks/autols.fish
        __fish_auto_ls = {
          body = "ls -AF --group-directories-first";
          onVariable = "PWD";
        };

        direnv = ''
          set -f op $argv[1]
          if test "$op" = "use"
            set -f env $argv[2]
            if test -n "$env"
              echo "use flake 'n9#\"$env\"'" | tee .envrc
            end
            command direnv allow
          else if test "$op" = "reuse"
            rm -rf .direnv
            command direnv reload
          else if test "$op" = "collect-garbage"
            set -f gcroots (find /nix/var/nix/gcroots/auto -not -type d | xargs readlink \
              | grep -F "/.direnv/" | string split "/.direnv/" -f 1 | sort | uniq)
            for d in $gcroots
              # TODO: Fish event is annoying, help me...
              echo "removing '$d'"
              bash -c "cd \"$d\" && rm -rf .direnv && direnv allow && eval \"\$(direnv export bash)\""
            end
            # nix-collect-garbage -d
          else
            command direnv $argv
          end
        '';

        # https://stackoverflow.com/questions/13713101/rsync-exclude-according-to-gitignore-hgignore-svnignore-like-filter-c
        rsync-git = ''
          set -f excludes "--exclude=/.git"
          for i in (git ls-files --exclude-standard -oi --directory)
            set -a excludes "--exclude=/$i"
          end
          rsync $excludes $argv
        '';

        # Run tide_reload after changes each time:
        tide_reload = ''
          set -eU (set -U | awk '/tide/ {print $1}')

          # what `tide configure` shows:
          tide configure --auto --style=Lean --prompt_colors='True color' --show_time='24-hour format' --lean_prompt_height='Two lines' --prompt_connection=Disconnected --prompt_spacing=Compact --icons='Few icons' --transient=No

          # customized items:
          set -U tide_whoami_bg_color normal
          set -U tide_whoami_color $tide_context_color_ssh
          set -U tide_whoami_icon
          set -U --prepend tide_left_prompt_items whoami
          set -U --erase tide_right_prompt_items[(contains -i context $tide_right_prompt_items)]
          set -U fish_greeting
        '';

        # https://github.com/IlanCosman/tide/blob/main/functions/_tide_item_nix_shell.fish
        # https://github.com/haslersn/any-nix-shell/blob/master/bin/nix-shell-info
        # The nix-shell will introdue some nix build environment in here, such
        # as $name or else, the mkDerivation just works like that :/
        _tide_item_nix_shell = ''
          if test -z "$IN_NIX_SHELL" -a -z "$IN_NIX_RUN"
            return
          end

          set -f pkgs $ANY_NIX_SHELL_PKGS
          if test -n "$name" -a "$name" != "shell"
            set -a pkgs " $name"
          end
          if test -n "$pkgs"
            set pkgs (echo "$pkgs $additional_pkgs" | xargs)
            set pkgs " ($pkgs)"
          end

          _tide_print_item nix_shell $tide_nix_shell_icon' ' "$IN_NIX_SHELL$pkgs"
        '';

        _tide_item_whoami = ''
          set -f indicator
          if test -n "$SSH_CONNECTION"
            set indicator "ssh $USER@$hostname"
          else if test -n "$WSL_DISTRO_NAME"
            set indicator "wsl"
          else if test "$HOSTNAME" = "dnd"
            set indicator "dnd"
          end

          if test -n "$indicator"
            _tide_print_item whoami $tide_whoami_icon' ' "$indicator %"
          end
        '';

        # Faster flamegraph explore:
        flame = ''
          set -f data $argv[1]
          if string match "*perf.data*" "$data"
            sudo perf script -i "$data" | inferno-collapse-perf
          end | flamelens $argv[2..]
        '';
      };

      shellInit = ''
        # To keep PATH cleans (by fish_add_path), we want a "pure" shell :)
        set -eU fish_user_paths

        # https://github.com/haslersn/any-nix-shell
        ${pkgs.any-nix-shell}/bin/any-nix-shell fish | source
      '';

      interactiveShellInit = ''
        # https://fishshell.com/docs/current/language.html#syntax-function-autoloading
        __fish_auto_ls

        # fzf, Ctrl+(R|V) Ctrl+Alt+(L|S|P)
        set -gx FZF_DEFAULT_OPTS --bind "alt-k:clear-query"

        # TODO: using home-manager?
        abbr --command git d "diff -b HEAD"
        abbr --command git s "status"
        abbr --command git a "add (git rev-parse --show-toplevel)"
        abbr --command git r "restore --staged --worktree"
        abbr --command git c "commit --amend --reset-author --no-edit"
      '';

      # TODO: Re-orgranize...
      shellAbbrs = {
        # ff = "fd --type f .";
        up = "upto";
        # ze = "zoxide query";
        # dh = "dirh";
        # dc = "cdh";
      };
    };

    # Make home-manager's fish work, for iterm2 use '/run/current-system/sw/bin/fish' shell.
    config.variant.nix-darwin.programs.fish.enable = true;
  };
}

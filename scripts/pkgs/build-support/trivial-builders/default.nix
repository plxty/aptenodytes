# Configuration builders, not a replacement for stdenv or software packaging.
{
  lib,
  system,
  toolchainId,
  shell,
}:
let
  builder = builtins.toFile "native-builder.sh" ''
    set -eo pipefail

    runHook() {
      local hook="$1"
      if [[ -n "''${!hook-}" ]]; then eval "''${!hook}"; fi
    }

    # Current upstream systemd helpers use structured attributes. Nix does not
    # export those attributes (or process passAsFile) into the environment.
    if [[ -e .attrs.sh ]]; then
      source .attrs.sh
      export PATH
      for outputName in "''${!outputs[@]}"; do
        export "$outputName=''${outputs[$outputName]}"
      done
      eval "$buildCommand"
    else
      source "$buildCommandPath"
    fi
  '';

  makeDerivation = attrs:
    let
      drv = builtins.derivation (
        (builtins.removeAttrs attrs [ "meta" "passthru" ])
        // {
          inherit system;
          builder = shell;
          args = [ "-e" builder ];
          passAsFile = lib.unique ([ "buildCommand" ] ++ (attrs.passAsFile or [ ]));
          PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
          nativeToolchainId = toolchainId;
          preferLocalBuild = true;
          allowSubstitutes = false;
        }
      );
    in
    drv // (attrs.passthru or { }) // {
      meta = attrs.meta or { };
      overrideAttrs = update:
        let
          changes = if builtins.isFunction update then update attrs else update;
          finalAttrs = attrs // (
            if builtins.isFunction changes then update finalAttrs attrs else changes
          );
        in
        makeDerivation finalAttrs;
    };
in
rec {
  runtimeShell = shell;
  runCommand = name: env: buildCommand:
    makeDerivation (env // { inherit name buildCommand; });
  runCommandLocal = runCommand;
  runCommandNoCC = runCommand;

  writeTextFile = {
    name,
    text,
    destination ? "",
    executable ? false,
    checkPhase ? "",
    meta ? { },
    passthru ? { },
    derivationArgs ? { },
  }:
    runCommand name (derivationArgs // {
      inherit text meta passthru;
      passAsFile = [ "text" ];
    }) ''
      target="$out"${lib.escapeShellArg destination}
      mkdir -p "$(dirname "$target")"
      if [[ -n "''${textPath-}" ]]; then
        cp "$textPath" "$target"
      else
        printf '%s' "$text" > "$target"
      fi
      chmod ${if executable then "755" else "644"} "$target"
      ${if checkPhase == null then "" else checkPhase}
    '';

  writeText = name: text: writeTextFile { inherit name text; };
  writeTextDir = destination: text: writeTextFile {
    inherit text;
    name = baseNameOf destination;
    destination = "/${destination}";
  };
  writeScript = name: text: writeTextFile {
    inherit name text;
    executable = true;
  };
  writeShellScript = name: text: writeTextFile {
    inherit name;
    text = "#!${shell}\n${text}";
    executable = true;
    checkPhase = "${lib.escapeShellArg shell} -n \"$target\"";
  };
  writeShellScriptBin = name: text: writeTextFile {
    inherit name;
    text = "#!${shell}\n${text}";
    destination = "/bin/${name}";
    executable = true;
    checkPhase = "${lib.escapeShellArg shell} -n \"$target\"";
    meta.mainProgram = name;
  };
}

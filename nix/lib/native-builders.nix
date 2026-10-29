{ lib, system, toolchainId, shell ? "/bin/bash", python ? "/usr/bin/python3" }:
let
  mk = attrs: let
    drv = builtins.derivation ((builtins.removeAttrs attrs [ "meta" "passthru" ]) // {
      inherit system;
      builder = shell;
      args = [ "-e" (builtins.toFile "native-builder.sh" ''
        # Upstream runCommand bodies may deliberately read unset variables.
        set -eo pipefail
        runHook() {
          local hook="$1"
          if [[ -n "''${!hook-}" ]]; then eval "''${!hook}"; fi
        }
        source "$buildCommandPath"
      '') ];
      passAsFile = lib.unique ([ "buildCommand" ] ++ (attrs.passAsFile or [ ]));
      PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      nativeToolchainId = toolchainId;
      preferLocalBuild = true;
      allowSubstitutes = false;
    });
  in drv // (attrs.passthru or { }) // {
    meta = attrs.meta or { };
    overrideAttrs = f: let
      changes = f attrs;
      updated = attrs // (if builtins.isFunction changes then f updated attrs else changes);
    in mk updated;
  };
in rec {
  runtimeShell = shell;
  runCommand = name: env: buildCommand: mk (env // { inherit name buildCommand; });
  runCommandLocal = runCommand;
  runCommandNoCC = runCommand;
  writeTextFile = {
    name, text, destination ? "", executable ? false, checkPhase ? "",
    meta ? { }, passthru ? { }, derivationArgs ? { }, ...
  }: runCommand name (derivationArgs // {
    inherit text meta passthru;
    passAsFile = [ "text" ];
  }) ''
    target="$out"${lib.escapeShellArg destination}
    mkdir -p "$(dirname "$target")"
    cp "$textPath" "$target"
    chmod ${if executable then "755" else "644"} "$target"
    ${if checkPhase == null then "" else checkPhase}
  '';
  writeText = name: text: writeTextFile { inherit name text; };
  writeTextDir = destination: text: writeTextFile {
    inherit text;
    name = baseNameOf destination;
    destination = "/${destination}";
  };
  writeScript = name: text: writeTextFile { inherit name text; executable = true; };
  writeShellScript = name: text: writeTextFile {
    inherit name;
    executable = true;
    text = "#!${shell}\n${text}";
    checkPhase = "${shell} -n \"$target\"";
  };
  writeShellScriptBin = name: text: writeTextFile {
    inherit name;
    destination = "/bin/${name}";
    executable = true;
    text = "#!${shell}\n${text}";
    checkPhase = "${shell} -n \"$target\"";
    meta.mainProgram = name;
  };
  buildSpec = name: spec: runCommand name {
    spec = builtins.toJSON spec;
    passAsFile = [ "spec" ];
  } ''
    ${python} ${./build.py} "$specPath" "$out"
  '';
}

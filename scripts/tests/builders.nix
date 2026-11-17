{ api, pkgs }:
let
  original = pkgs.writeText "native-text" "original";
  changed = original.overrideAttrs (old: { text = old.text + "-changed"; });
  recursive = original.overrideAttrs (final: old: {
    suffix = "recursive";
    text = "${old.text}-${final.suffix}";
  });
  structured = pkgs.runCommand "native-structured-command" {
    __structuredAttrs = true;
    text = "structured";
  } ''
    printf '%s' "$text" > "$out"
  '';
  structuredText = pkgs.writeTextFile {
    name = "native-structured-text";
    text = "structured text";
    derivationArgs.__structuredAttrs = true;
  };
  script = pkgs.writeShellScriptBin "native-script" "printf native-script";
  sourceArtifact = api.mkSystem {
    inherit pkgs;
    modules = [{ environment.etc.provider.source = ./fixtures/provider; }];
  };
in
pkgs.runCommand "aptenodytes-native-builders-check" { } ''
  test "$(cat ${original})" = original
  test "$(cat ${changed})" = original-changed
  test "$(cat ${recursive})" = original-recursive
  test "$(cat ${structured})" = structured
  test "$(cat ${structuredText})" = 'structured text'
  test -x ${pkgs.lib.getExe script}
  test "$(${pkgs.lib.getExe script})" = native-script
  test "$(cat ${sourceArtifact.artifact}/etc/provider)" = noauth
  mkdir -p "$out"
''

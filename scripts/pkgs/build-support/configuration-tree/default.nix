{ lib, runCommand, python }:
{ name ? "aptenodytes-system-config", manifest }:
runCommand name {
  manifest = builtins.toJSON manifest;
  passAsFile = [ "manifest" ];
} ''
  ${lib.escapeShellArg python} ${./builder.py} "$manifestPath" "$out"
''

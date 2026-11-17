# Package-shaped native references for upstream types.package/getBin/getExe.
# These do not install, build, discover, or check any host package.
{
  name,
  prefix ? "/usr",
  executables ? { },
  mainProgram ? null,
}:
let
  package = {
    type = "derivation";
    isNative = true;
    inherit name executables;
    outPath = prefix;
    outputs = [ "out" ];
    out = package;
    meta = if mainProgram == null then { } else { inherit mainProgram; };
  };
in
package

# Native declarative configuration builds

This is the first buildable version of the configuration adapter. Nix evaluates
pinned upstream modules and produces store artifacts; Gentoo supplies applications
and build tools. It does not install packages, modify the current system, or replace
`burn.sh` and the existing profiles.

## Build

The examples target `x86_64-linux`. Enable Nix's `nix-command` and `flakes`
features. The build host needs `/bin/bash`, `/usr/bin/python3`, PyYAML, and native
GNU coreutils. The existing network generator used by the checks needs Python 3.13.
On Gentoo, supply these through Portage, including `dev-python/pyyaml` for the
selected system Python. Recursive Home Manager file trees additionally need
`lndir`; the included example does not use recursive trees.

Native executables and libraries must be visible in the Nix build sandbox. For
an initial Gentoo host setup, the Nix daemon can expose the native tool directories:

```ini
# nix.conf: adjust these paths to the host's filesystem layout.
sandbox = true
sandbox-fallback = false
extra-sandbox-paths = /usr /bin /sbin /lib /lib64
```

These are broad host-directory bindings, not a hermetic tool snapshot. They let
the builder consume the host's tools, libraries and Python modules. Nix still
controls its build outputs and namespace sandbox. No root files or services are
changed by the example builds. A narrower, versioned tool snapshot is future work.

```sh
nix build .#system-example --out-link /tmp/aptenodytes-system
nix build .#home-example --out-link /tmp/aptenodytes-home
nix build .#pseudo-env-example --out-link /tmp/aptenodytes-environment
nix flake check -L
python3 -m unittest discover -s tests/config -v
```

Do not interpret `nix flake check` as a live networking or activation test.

## Interfaces

The root flake exports `lib.mkPkgs`, `lib.mkSystem`, and `lib.mkHome`. For example,
from another flake that imports this repository:

```nix
let
  pkgs = inputs.aptenodytes.lib.mkPkgs {
    system = "x86_64-linux";
    toolchainId = "gentoo-tools-2026-10-29";
  };
in (inputs.aptenodytes.lib.mkHome {
  inherit pkgs;
  modules = [ ./home.nix ];
}).artifact
```

`toolchainId` participates in derivation hashes. Update it when changing native
build tools or libraries; otherwise Nix can reuse a cached output even after a
host tool upgrade. It is an explicit identity, not an automatically verified
fingerprint. The example flake uses `native-host-v1`. Flake locks pin module
sources, not the external host environment.

`mkPkgs` uses the upstream package set for library/types and overrides the
selected native applications, builders and format generators. The tested
generation graph uses native Bash for every derivation and native Python/PyYAML
for YAML. Unsupported modules may need more mappings; this is not a complete
replacement for every package/helper in nixpkgs.

`nix/lib/native-pkgs.nix` is the explicit runtime mapping list. Native descriptors
support string interpolation and the package operations needed by the selected
modules. They are not independently buildable packages. `nativeFiles` declares
which links a package contributes to a user environment; an empty mapping still
allows direct `/usr` references from modules.

### pseudoBuildEnv

The module-facing `pkgs.buildEnv` is implemented by `pseudoBuildEnv`. It supports
`name`, `paths`, `pathsToLink`, `extraOutputsToInstall`, `postBuild`, `meta`, and
`passthru`. Native inputs contribute only their declared links; their targets
need not exist and are never traversed. Real generated package directories are
merged without following directory symlinks, retaining HM's session files.

Identical links are deduplicated; conflicting files or parent links fail. This
version does not implement upstream priorities, collision override flags,
propagated packages or closure expansion. Unknown arguments fail at evaluation.
`postBuild` runs with native tools after the links are assembled; callers must
use commands appropriate for this environment.

The native builders implement the subset exercised here: `runCommand` variants,
text/script writers, `overrideAttrs`, JSON, YAML 1.1 and text/INI generators.
They do not provide the full stdenv setup-hook or compiler environment. Do not
use them as arbitrary software-package builders.

## Examples and artifact contract

`system-example` imports the unmodified pinned networkd and PPP modules, using
the small system schema in `modules/system-base.nix` and PPP compatibility
settings in `modules/pppd.nix`. `examples/evil.nix` describes the current router.

The artifact contains `etc/`, `usr/lib/systemd/network/`, and `manifest.json`.
The schema-1 manifest has `kind = "system"`, owned `files`, enablement/alias
`links`, expected `vendorUnits`, and service restart/reload policy. Native vendor
services receive drop-ins; complete PPP instances receive full units. Masked
units point to `/dev/null`. Credentials stay at `/etc/ppp/keys/ppp-wan`; they are
not read during evaluation or copied into the store.

`home-example` uses HM's minimal module list plus the declarations needed by Git
and shell integration. It generates Git config, YAML, a systemd user unit and
HM session variables. The artifact has `home-files`, `home-path`, and a manifest
identifying the example user. `home-path` retains generated session files alongside
native Git links. Nix-specific glibc locale variables are disabled, and MIME/man
installation is off by default; Gentoo owns those facilities.

Home artifacts deliberately do not execute HM's activation package. Arbitrary
HM `onChange`/activation hooks are not yet integrated. The included example only
tests generation, not complete support for arbitrary HM configurations.

`pseudo-env-example` combines a generated file with a link to a deliberately
absent native executable. This demonstrates that runtime existence checks are
not part of the environment builder.

## Validation and remaining work

The automated checks compare all 11 networkd files to the actual existing
`gen-network.py` output. PPP peer contents match byte-for-byte; service directives
match the old template instance except for the store pre-start script and the
added restart trigger. They also check the Git/YAML/user-unit outputs, retained
HM session variables, native links, and unit enablement/aliases.

The initial cloud run built the examples and passed the checks. Its recursive
derivation graph used `/bin/bash` for all system/home builds, with no Nix compiler
or application packages in the deployed closure. A strict sandbox attempt with
fallback disabled failed before building because the container does not support
the required kernel namespaces. Therefore strict sandbox execution of the host
tools remains **unverified**; successful cloud builds used the existing local
runner with sandbox disabled. No Gentoo machine was activated or dialed.

A production activator remains separate work: register real GC roots, reconcile
only owned files, respect user contexts, apply service policies and handle network
device changes. `needrestart` or equivalent remains necessary for native binary
updates. Merely creating `/etc/aptenodytes/current` is not sufficient GC registration.

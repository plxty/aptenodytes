# Native declarative configuration artifacts

This is a PPP-only proof of concept for replacing configuration generation in
`ridgeni` profile packages. Portage still supplies applications and build tools.
Nix only evaluates configuration and builds store artifacts. Nothing here changes
profiles, installs packages, activates files, runs `pppd`, or calls `systemctl`.
The existing PPP ebuild and profile are unchanged.

## Layout and interfaces

- `lib/`: `mkPkgs`, `mkSystem`, module evaluation and artifact manifests.
- `modules/`: the small configuration schema and native PPP adaptation.
- `pkgs/top-level/`: the explicit native package set; **no upstream package-set
  import or Nix-package fallback**.
- `pkgs/build-support/`: native text/script builders, native package descriptors,
  and the configuration-tree builder beside its Python implementation.
- `examples/pppd.nix`: the `ppp-wan`/`eth3` intent from `profiles/iglu/evil`, without
  bringing in networkd, Home Manager, or the rest of the host configuration.
- `tests/`: filesystem unit tests, evaluation checks and built-artifact comparisons.

`mkPkgs` requires a Nix `system` and an explicit `toolchainId`. Optional `shell`
and `python` strings default to `/usr/bin/bash` and `/usr/bin/python3`. It exposes
only the native package references and configuration builders implemented here.
Descriptors provide package-shaped values for upstream `types.package` and
`lib.getBin`/`lib.getExe`; they do not install packages or check their existence.
Unknown packages and unsupported builder interfaces fail instead of falling back.

The upstream PPP module's options, peer generation and systemd rendering are
reused. Local adaptations preserve the ridgeni instance name, command arguments,
hardening and PPPoE preparation. The `libredirect` descriptor is only an evaluation
compatibility reference: upstream forces its string before the native override
removes `LD_PRELOAD`. No libredirect library is built, required or loaded.

No tool preflight is performed. Users supply the tools; executing a missing build
tool fails the build. Referenced runtime applications and credentials need not
exist on the build host. Credentials remain external path strings, never store
inputs. Because they are emitted as unquoted PPP tokens, credential paths reject
whitespace, quotes, backslashes and `#`.

This stage emits complete owned service units, not timers or vendor drop-ins.
`startAt` and `overrideStrategy = "asDropin"` are rejected rather than silently
ignored. Literal Nix-path configuration sources are copied into the store and
retained as artifact dependencies; native path strings remain external references.

## Build environment

The example targets `x86_64-linux`, using native Bash, GNU coreutils and Python 3.
Checks also run the existing `gen-network.py`, which requires Python 3.13 or newer.
No third-party Python modules are needed for this stage.

Enable `nix-command` and `flakes`, either in your Nix configuration or per command:

```sh
nix --extra-experimental-features 'nix-command flakes' build .#pppd-example --no-link --print-out-paths
```

The lock pins the same nixpkgs revision as the prepared `~/nixpkgs` checkout at
implementation time (`33693d87d79fb2fa9c3c850e96f04b57f462af09`). To explicitly use
another local checkout without changing the lock:

```sh
nix --extra-experimental-features 'nix-command flakes' build .#pppd-example \
  --override-input nixpkgs "git+file://$HOME/nixpkgs" --no-write-lock-file \
  --no-link --print-out-paths
```

Native tools, their interpreters, dynamic linker and libraries must be visible
inside the build sandbox. On this merged-`/usr` Gentoo host, the tested bindings
are:

```ini
sandbox = true
sandbox-fallback = false
sandbox-paths = /usr /bin=/usr/bin /sbin=/usr/bin /lib=/usr/lib /lib64=/usr/lib64
```

This **replaces** Gentoo's default sandbox shell mapping. Adapt the paths for
other layouts. Exposing the whole native tool/library tree is broad and
non-hermetic; these are read-only build-sandbox mounts, not a versioned toolchain
snapshot. In particular, the flake lock does not pin Gentoo packages. Update
`toolchainId` when changing the host tools/libraries to invalidate cached builds.
It is a manual cache identity, not an automatically verified fingerprint.

Daemon sandbox settings require administrator configuration or a trusted caller;
an untrusted client's sandbox-path overrides are ignored. The implementation does
not change these settings or disable sandboxing.

### Unprivileged sandbox validation

A separate user-owned store can validate the complete build without changing the
shared daemon configuration. On this Gentoo host, user namespaces and the native
bindings above allow:

```sh
store="${XDG_CACHE_HOME:-$HOME/.cache}/aptenodytes/nix"
nix --extra-experimental-features 'nix-command flakes' flake check -L \
  --store "$store" \
  --option sandbox true --option sandbox-fallback false \
  --option sandbox-paths '/usr /bin=/usr/bin /sbin=/usr/bin /lib=/usr/lib /lib64=/usr/lib64'
nix --extra-experimental-features 'nix-command flakes' build .#pppd-example \
  --store "$store" --no-link --print-out-paths \
  --option sandbox true --option sandbox-fallback false \
  --option sandbox-paths '/usr /bin=/usr/bin /sbin=/usr/bin /lib=/usr/lib /lib64=/usr/lib64'
```

The printed logical paths are `/nix/store/...`; physical files for this store are
under `$store/nix/store/`. Inspect them using that physical prefix, or pass it as
`--store-root` to `tests/integration.py`. This does not configure the shared store
for native builds. For a review copy in the shared store, without trusting unsigned
input-addressed outputs, Nix can content-address the artifact and its references:

```sh
nix --extra-experimental-features nix-command store make-content-addressed \
  --from "$store" --to daemon /nix/store/…-aptenodytes-system-config
```

This produces different store paths, not the original derivation's output path;
it does not enable subsequent native builds through the daemon.

## Artifact contract

The example output contains:

```text
etc/ppp/peers/ppp-wan -> generated store file
etc/systemd/system/pppd@ppp-wan.service -> generated store unit
etc/systemd/system/multi-user.target.wants/pppd@ppp-wan.service -> ../pppd@ppp-wan.service
manifest.json
```

The schema-1 manifest records `kind = "system"`, owned `files`, enablement/alias
`links`, and service change policy/triggers. Other generated store objects contain
the native-shell pre-start helper and the peer-file restart trigger. There are no
credential files, installed applications or activation scripts in the artifact.

`pkgs.configurationTree { manifest = ...; }` only assembles symlinks and writes the
manifest. Its Python builder does not serialize YAML, merge package environments,
or dereference link targets. It rejects unsafe destinations, parent-link
collisions, conflicting entries and attempts to replace `manifest.json`.

## Checks

```sh
python3 -m unittest discover -s scripts/tests -v
nix --extra-experimental-features 'nix-command flakes' flake check -L
python3 scripts/tests/integration.py --artifact /nix/store/…-aptenodytes-system-config
```

The flake checks exercise native text/script/structured-attribute builders,
module assertions, strict native package references, disabled/manual peers,
masking and collisions. The artifact comparison verifies byte-for-byte PPP peer
output against `gen-network.py`, all static service directives against the
existing ridgeni template, the generated helper, restart trigger and enablement
link. This is generation validation, not a live PPP or activation test.

Not implemented: networkd and other ridgeni generators, Home Manager,
`pseudoBuildEnv`, extra format generators, software-package builders, deployment,
GC-root management or service activation.

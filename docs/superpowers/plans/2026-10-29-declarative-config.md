# Declarative Configuration Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the agreed minimal build experiment on a new GitHub branch: native configuration builders, pseudoBuildEnv, system examples and a Home Manager example.

**Architecture:** A pinned flake supplies upstream modules and types. A module-facing package set maps applications to native paths and uses native Bash/Python/PyYAML to produce store artifacts. pseudoBuildEnv combines declared native links with generated store files without traversing native prefixes.

**Tech Stack:** Nix flakes/modules, Python 3, PyYAML, native POSIX tools and Bash.

**Spec:** [First-stage design](../specs/2026-10-29-declarative-config.md).

## Global Constraints

- Use the name `pseudoBuildEnv`; prioritize native tools in both build and runtime contexts.
- Pin nixpkgs and Home Manager; share nixpkgs through `follows`; no upstream source patches.
- Preserve generated files while accepting dangling native executable references.
- Do not change burn.sh, Portage/profile workflows or install/apply system configuration.
- This iteration implements the minimum build experiment. Production activation and native-tool snapshots remain later work; document the artifact contract and sandbox requirements now.
- Push `codex/declarative-config`; do not create a PR.

## Review Focus

- Native targets may not exist: construction must never follow them.
- Generated files may collide with native links or escape the output: fail before writing outside the output.
- Home Manager adds generated session files to home.packages: retain them.
- Host tools can change without flake inputs changing: expose a toolchain identity for cache invalidation and state the reproducibility boundary.
- Cloud namespaces can prohibit strict sandboxing: report that limit, never claim a sandboxed test silently fell back.

## Task 1: Native builders and pseudoBuildEnv

**Files:** `nix/lib/native-builders.nix`, `nix/lib/pseudo-build-env.nix`, `nix/lib/build.py`, `nix/lib/native-pkgs.nix`, `tests/config/test_build.py`.

**Interfaces:** native builder functions provide runCommand/writeText/writeTextFile/script writers and format generators; pseudoBuildEnv accepts native descriptors with `nativeFiles` and real store output directories. The Python builder consumes JSON specifications and writes one output tree or YAML file.

- [ ] Add failing tests for dangling native links, generated-file preservation, collisions, path traversal, filtering and native YAML generation.
- [ ] Implement the native builder subset and pseudoBuildEnv; run `/usr/bin/python3 -m unittest discover -s tests/config -v` until green.
- [ ] Commit the independently tested backend.

## Task 2: Pinned flake and module integration

**Files:** `flake.nix`, `flake.lock`, `nix/lib/default.nix`, `nix/modules/*.nix`, `nix/examples/*.nix`, `tests/config/integration.py`.

**Interfaces:** `lib.mkPkgs` produces the module-facing package set; `packages.<system>.system-example`, `home-example` and `pseudo-env-example` produce inspectable store artifacts; `checks` verify the same outputs. The root manifest records owned files and service policy, without activation side effects.

- [ ] Add integration assertions for the real baseline generator, PPP peer/unit parity, native-only runtime closures and retained HM session files.
- [ ] Integrate the already verified upstream networkd/PPP modules and an HM config using native Git plus generated YAML.
- [ ] Build all examples, run the assertions and probe strict sandboxing with fallback disabled.
- [ ] Commit the integrated examples and pinned inputs.

## Task 3: Documentation, review and push

**Files:** `nix/README.md`, root README link, design/plan execution notes.

- [ ] Document native tool requirements, explicit sandbox exposure, toolchain identity, supported builder subset and deferred activation.
- [ ] Run all relevant checks and a fresh whole-branch review; resolve important findings with regression coverage.
- [ ] Commit documentation/fixes, push the authorized new branch and verify remote HEAD matches local HEAD. No PR.

## Execution notes

- Permission preflight: GitHub reports push permission and push dry-run succeeds.
- Workspace choice: use the clean dedicated cloud checkout on the explicitly requested new branch; no additional worktree is needed.
- Execution is already authorized by the user; proceed inline without another plan approval round.

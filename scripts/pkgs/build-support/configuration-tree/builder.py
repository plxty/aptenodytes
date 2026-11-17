"""Assemble a configuration tree without inspecting its native symlink targets.

Usage: builder.py MANIFEST_JSON OUTPUT

The input is the artifact manifest itself. Its ``files`` and ``links`` objects
map relative output names to symlink target strings. Metadata such as ``schema``,
``kind`` and ``services`` is preserved, not interpreted. The complete manifest is
written to OUTPUT/manifest.json; all other entries are symlinks. Validation and
serialization finish before OUTPUT is created. No target is statted, traversed,
or dereferenced, so native targets need not exist on the build host.
"""

import argparse
import json
import os
import sys
from pathlib import Path, PurePosixPath


def validate_destination(name):
    """Reject unsafe names, including aliases for the reserved manifest file."""
    if (
        not isinstance(name, str)
        or PurePosixPath(name).is_absolute()
        or any(part in {"", ".", ".."} for part in name.split("/"))
        or "\0" in name
    ):
        raise ValueError(f"invalid relative output path: {name!r}")
    if name.split("/", 1)[0] == "manifest.json":
        raise ValueError(f"manifest.json is reserved: {name!r}")
    # Check filesystem encoding without inspecting the destination or target.
    os.fsencode(name)


def collect_links(manifest):
    """Merge the two maps and validate the entire layout before writing it."""
    if not isinstance(manifest, dict):
        raise TypeError("manifest must be a JSON object")

    links = {}
    for field in ("files", "links"):
        entries = manifest.get(field)
        if not isinstance(entries, dict):
            raise TypeError(f"manifest {field!r} must be an object")
        for name, target in entries.items():
            validate_destination(name)
            if not isinstance(target, str) or not target or "\0" in target:
                raise ValueError(
                    f"target for {name!r} must be a nonempty string without NUL"
                )
            os.fsencode(target)
            if name in links and links[name] != target:
                raise ValueError(f"conflicting targets for output path: {name!r}")
            links[name] = target

    for name in sorted(links):
        for parent in PurePosixPath(name).parents:
            if str(parent) in links:
                raise ValueError(f"parent link collision: {str(parent)!r} / {name!r}")
    return links


def build_tree(manifest, output):
    """Create a new output directory containing validated links and manifest."""
    links = collect_links(manifest)
    manifest_bytes = (
        json.dumps(manifest, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    ).encode("utf-8")

    output = Path(output)
    output.mkdir(parents=True)
    for name, target in sorted(links.items()):
        destination = output / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.symlink_to(target)
    (output / "manifest.json").write_bytes(manifest_bytes)


def main(argv=None):
    """Run the CLI, reporting input and filesystem errors without tracebacks."""
    parser = argparse.ArgumentParser(
        description="Assemble a configuration symlink tree."
    )
    parser.add_argument("manifest_json", metavar="MANIFEST_JSON")
    parser.add_argument("output", metavar="OUTPUT")
    args = parser.parse_args(argv)
    try:
        with open(args.manifest_json, encoding="utf-8") as source:
            manifest = json.load(source)
        build_tree(manifest, args.output)
    except json.JSONDecodeError as error:
        parser.exit(1, f"configuration-tree: invalid JSON: {error}\n")
    except (TypeError, ValueError, OSError, RecursionError) as error:
        parser.exit(1, f"configuration-tree: {error}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())

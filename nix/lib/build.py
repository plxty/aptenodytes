"""Native configuration builders. Never walk or dereference native packages."""
import json
import os
from pathlib import Path, PurePosixPath
import sys


def relative(name):
    path = PurePosixPath(name)
    if not name or path.is_absolute() or any(p in {".", ".."} for p in name.split("/")):
        raise ValueError(f"expected a relative output path without traversal: {name!r}")
    return str(path)


def add_link(links, name, target):
    name = relative(name)
    if name in links and links[name] != target:
        raise ValueError(f"link collision: {name}")
    links[name] = target


def write_links(output, links):
    # Check the whole layout before making any symlinks, including directory
    # symlinks whose children could otherwise redirect writes outside output.
    for name in links:
        for parent in PurePosixPath(name).parents:
            if str(parent) in links:
                raise ValueError(f"parent link collision: {parent} / {name}")
    output.mkdir(parents=True)
    for name, target in sorted(links.items()):
        dest = output / name
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.symlink_to(target)


def environment(spec, output):
    links = {}
    prefixes = spec.get("pathsToLink", ["/"])

    def selected(name):
        return any(p == "/" or name == p.lstrip("/") or name.startswith(p.lstrip("/").rstrip("/") + "/")
                   for p in prefixes)

    for package in spec["paths"]:
        if "nativeFiles" in package:
            entries = package["nativeFiles"].items()
        else:
            source = Path(package["store"])
            if not source.is_dir():
                raise ValueError(f"generated environment input must be a directory: {source}")
            entries = []
            for directory, dirs, files in os.walk(source, followlinks=False):
                for name in list(dirs):
                    if (Path(directory) / name).is_symlink():
                        dirs.remove(name)
                        files.append(name)
                for name in files:
                    file = Path(directory) / name
                    entries.append((str(file.relative_to(source)), str(file)))
        for name, target in entries:
            name = relative(name)
            if selected(name):
                add_link(links, name, target)
    write_links(output, links)


def build(spec, output):
    if spec["kind"] == "yaml":
        import yaml
        output.write_text(yaml.safe_dump(spec["value"], allow_unicode=True, sort_keys=True), encoding="utf-8")
    elif spec["kind"] == "environment":
        environment(spec, output)
    elif spec["kind"] == "tree":
        links = {}
        for entries in (spec.get("files", {}), spec.get("links", {})):
            for name, target in entries.items():
                add_link(links, name, target)
        if "manifest.json" in links:
            raise ValueError("manifest.json is reserved for the artifact manifest")
        write_links(output, links)
        (output / "manifest.json").write_text(json.dumps(spec.get("manifest", {}), indent=2) + "\n")
    else:
        raise ValueError(f"unsupported build kind: {spec['kind']}")


if __name__ == "__main__":
    try:
        with open(sys.argv[1], encoding="utf-8") as source:
            build(json.load(source), Path(sys.argv[2]))
    except (ValueError, OSError) as error:
        sys.exit(str(error))

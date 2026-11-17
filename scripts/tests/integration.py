"""Inspect a built PPP artifact; never activate it or run pppd/systemctl."""

import argparse
import json
import os
import subprocess
import tempfile
from collections import defaultdict
from pathlib import Path


def ini(text):
    """Parse the repeated directives used here, normalizing systemd booleans."""
    sections = defaultdict(list)
    block = None
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(("#", ";")):
            continue
        if line.startswith("[") and line.endswith("]"):
            block = defaultdict(list)
            sections[line[1:-1]].append(block)
        else:
            key, value = line.split("=", 1)
            block[key].append({"yes": "true", "no": "false"}.get(value, value))
    return dict(sections)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", required=True)
    parser.add_argument(
        "--repo", type=Path, default=Path(__file__).resolve().parents[2]
    )
    parser.add_argument("--store-root", default="/nix/store")
    args = parser.parse_args()

    def physical(path):
        # Also permits inspection of a user-owned test store whose logical
        # paths are /nix/store but whose physical root is elsewhere.
        path = str(path)
        for _ in range(40):
            if path.startswith("/nix/store/"):
                path = args.store_root + path[len("/nix/store") :]
            resolved = os.path.realpath(path)
            if resolved == path:
                return Path(path)
            path = resolved
        raise AssertionError(f"symlink loop: {path}")

    artifact = physical(args.artifact)
    manifest = json.loads((artifact / "manifest.json").read_text())
    assert manifest["schema"] == 1 and manifest["kind"] == "system"
    peer_name = "etc/ppp/peers/ppp-wan"
    unit_name = "etc/systemd/system/pppd@ppp-wan.service"
    enablement = "etc/systemd/system/multi-user.target.wants/pppd@ppp-wan.service"
    assert set(manifest["files"]) == {peer_name, unit_name}
    assert manifest["links"] == {enablement: "../pppd@ppp-wan.service"}
    assert set(manifest["services"]) == {"pppd@ppp-wan.service"}
    expected = {**manifest["files"], **manifest["links"]}
    for name, target in expected.items():
        assert os.readlink(artifact / name) == target, name
    leaves = {
        str(path.relative_to(artifact))
        for path in artifact.rglob("*")
        if path.is_symlink() or path.is_file()
    }
    assert leaves == set(expected) | {"manifest.json"}, leaves

    with tempfile.TemporaryDirectory() as temp:
        subprocess.run(
            [
                "/usr/bin/bash",
                "-c",
                'set -a; source "$1"; exec /usr/bin/python3 "$2" pppoe "$3"',
                "baseline",
                str(args.repo / "profiles/iglu/evil/make.defaults"),
                str(args.repo / "scripts/gen-network.py"),
                temp,
            ],
            check=True,
        )
        peer = physical(manifest["files"][peer_name])
        assert peer.read_bytes() == (Path(temp) / "ppp-wan").read_bytes()
        assert "file /etc/ppp/keys/ppp-wan\n" in peer.read_text()

    unit_text = physical(manifest["files"][unit_name]).read_text()
    unit = ini(unit_text)
    old_unit = ini(
        (args.repo / "net-dialup/ppp/files/pppd@.service")
        .read_text()
        .replace("%i", "ppp-wan")
    )
    trigger = unit["Unit"][0].pop("X-Restart-Triggers")[0]
    assert physical(trigger).read_text() == manifest["files"][peer_name]
    helper = unit["Service"][0].pop("ExecStartPre")[0]
    old_unit["Service"][0].pop("ExecStartPre")
    assert unit == old_unit, (unit, old_unit)
    helper_path = physical(helper)
    helper_text = helper_path.read_text()
    assert helper_text.startswith("#!/usr/bin/bash\n")
    assert "exec /usr/bin/ip link set up dev eth3" in helper_text
    assert os.access(helper_path, os.X_OK)
    subprocess.run(["/usr/bin/bash", "-n", str(helper_path)], check=True)
    assert "LD_PRELOAD" not in unit_text and "NIX_REDIRECTS" not in unit_text
    assert "/run/current-system" not in unit_text
    assert not (artifact / "etc/ppp/keys").exists()
    print("PASS: PPP peer matches gen-network.py; unit matches ridgeni template")
    print(
        "PASS: native helper, restart trigger, manifest, and relative enablement link"
    )


if __name__ == "__main__":
    main()

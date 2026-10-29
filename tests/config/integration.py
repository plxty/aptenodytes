"""Compare real flake artifacts to the existing generator and native contracts."""
import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import subprocess
import tempfile

import yaml


def ini(text):
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
    parser = argparse.ArgumentParser()
    parser.add_argument("--system", required=True)
    parser.add_argument("--home", required=True)
    parser.add_argument("--environment", required=True)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--store-root", default="/nix/store")
    args = parser.parse_args()

    def physical(path):
        path = str(path)
        for _ in range(30):
            if path.startswith("/nix/store/"):
                path = args.store_root + path[len("/nix/store"):]
            resolved = os.path.realpath(path)
            if resolved == path:
                return Path(path)
            path = resolved
        raise AssertionError(f"symlink loop: {path}")

    system = physical(args.system)
    manifest = json.loads((system / "manifest.json").read_text())
    assert manifest["schema"] == 1
    assert manifest["kind"] == "system"
    with tempfile.TemporaryDirectory() as temp:
        subprocess.run([
            "/bin/bash", "-c", 'set -a; source "$1"; exec /usr/bin/python3 "$2" "*" "$3"',
            "baseline", str(args.repo / "profiles/iglu/evil/make.defaults"),
            str(args.repo / "scripts/gen-network.py"), temp,
        ], check=True)
        names = sorted(p.name for p in Path(temp).iterdir() if p.suffix in {".network", ".netdev", ".link"})
        assert len(names) == 11
        for name in names:
            source = manifest["files"][f"usr/lib/systemd/network/{name}"]
            assert ini(physical(source).read_text()) == ini((Path(temp) / name).read_text()), name
        peer = physical(manifest["files"]["etc/ppp/peers/ppp-wan"])
        assert peer.read_bytes() == (Path(temp) / "ppp-wan").read_bytes()

    unit_text = physical(manifest["files"]["etc/systemd/system/pppd@ppp-wan.service"]).read_text()
    unit = ini(unit_text)
    old_unit = ini((args.repo / "net-dialup/ppp/files/pppd@.service").read_text().replace("%i", "ppp-wan"))
    trigger = unit["Unit"][0].pop("X-Restart-Triggers")[0]
    assert physical(trigger).read_text() == manifest["files"]["etc/ppp/peers/ppp-wan"]
    helper = unit["Service"][0].pop("ExecStartPre")[0]
    old_unit["Service"][0].pop("ExecStartPre")
    assert unit == old_unit
    assert "exec /bin/ip link set up dev eth3" in physical(helper).read_text()
    assert "LD_PRELOAD" not in unit_text and "/run/current-system" not in unit_text
    assert manifest["links"]["etc/systemd/system/multi-user.target.wants/pppd@ppp-wan.service"] == "../pppd@ppp-wan.service"
    assert manifest["links"]["etc/systemd/system/dbus-org.freedesktop.network1.service"] == "/usr/lib/systemd/system/systemd-networkd.service"

    home = physical(args.home)
    home_files = physical(home / "home-files")
    git_config = physical(home_files / ".config/git/config").read_text()
    assert 'defaultBranch = "main"' in git_config
    config = yaml.safe_load(physical(home_files / ".config/aptenodytes/example.yaml").read_text())
    assert config == {"command": "/usr/bin/git", "enabled": True, "values": ["yes", 2, None]}
    home_path = physical(home / "home-path")
    assert os.readlink(home_path / "bin/git") == "/usr/bin/git"
    assert "APTENODYTES_EXAMPLE" in physical(home_path / "etc/profile.d/hm-session-vars.sh").read_text()
    user_unit = physical(home_files / ".config/systemd/user/native-example.service").read_text()
    assert "ExecStart=/usr/bin/git --version" in user_unit
    environment = physical(args.environment)
    assert os.readlink(environment / "bin/not-installed") == "/native-missing/bin/tool"
    assert physical(environment / "etc/generated").read_text() == "retained\n"
    print("PASS: 11 networkd files, PPP peer/unit, native helper and enablement")
    print("PASS: Home Manager Git/YAML/user unit, retained session vars, dangling native reference")


if __name__ == "__main__":
    main()

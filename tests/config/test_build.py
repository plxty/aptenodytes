import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


BUILDER = Path(__file__).resolve().parents[2] / "nix/lib/build.py"


class NativeBuildTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "out"

    def run_builder(self, spec):
        source = self.root / "spec.json"
        source.write_text(json.dumps(spec))
        return subprocess.run(
            [sys.executable, str(BUILDER), str(source), str(self.output)],
            capture_output=True, text=True,
        )

    def test_native_target_can_be_missing(self):
        result = self.run_builder({"kind": "environment", "paths": [
            {"nativeFiles": {"bin/not-installed": "/native-missing/bin/tool"}},
        ]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(self.output / "bin/not-installed"), "/native-missing/bin/tool")

    def test_generated_session_files_survive_native_package_merge(self):
        package = self.root / "generated"
        (package / "etc/profile.d").mkdir(parents=True)
        (package / "etc/profile.d/hm-session-vars.sh").write_text("export TEST=1\n")
        result = self.run_builder({"kind": "environment", "paths": [
            {"nativeFiles": {"bin/git": "/usr/bin/git"}}, {"store": str(package)},
        ]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.output / "etc/profile.d/hm-session-vars.sh").read_text(), "export TEST=1\n")

    def test_generated_directory_symlinks_are_not_traversed(self):
        package = self.root / "generated"
        package.mkdir()
        (package / "share").symlink_to("/native-missing/share")
        result = self.run_builder({"kind": "environment", "paths": [{"store": str(package)}]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / "share").is_symlink())

    def test_generated_root_symlink_cannot_enumerate_external_tree(self):
        outside = self.root / "external"
        outside.mkdir()
        (outside / "must-not-be-imported").write_text("host data")
        package = self.root / "generated"
        package.symlink_to(outside, target_is_directory=True)
        result = self.run_builder({"kind": "environment", "paths": [{"store": str(package)}]})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("root symlink", result.stderr)
        self.assertFalse(self.output.exists())

    def test_conflicting_files_fail(self):
        result = self.run_builder({"kind": "environment", "paths": [
            {"nativeFiles": {"bin/tool": "/usr/bin/one"}},
            {"nativeFiles": {"bin/tool": "/usr/bin/two"}},
        ]})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("collision", result.stderr)

    def test_link_parent_cannot_redirect_writes(self):
        result = self.run_builder({"kind": "environment", "paths": [
            {"nativeFiles": {"bin": str(self.root), "bin/escape": "/usr/bin/tool"}},
        ]})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("collision", result.stderr)
        self.assertFalse((self.root / "escape").exists())

    def test_absolute_and_traversal_destinations_fail(self):
        for name in ["../escaped", "/etc/escaped", "bin/../escaped"]:
            with self.subTest(name=name):
                result = self.run_builder({"kind": "environment", "paths": [
                    {"nativeFiles": {name: "/usr/bin/tool"}},
                ]})
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("relative", result.stderr)

    def test_paths_to_link_filters_native_and_generated_files(self):
        package = self.root / "generated"
        (package / "share").mkdir(parents=True)
        (package / "share/example").write_text("data")
        result = self.run_builder({"kind": "environment", "pathsToLink": ["/bin"], "paths": [
            {"nativeFiles": {"bin/git": "/usr/bin/git", "share/git": "/usr/share/git"}},
            {"store": str(package)},
        ]})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.output / "bin/git").is_symlink())
        self.assertFalse((self.output / "share").exists())

    def test_yaml_preserves_nested_values_and_native_paths(self):
        import yaml
        value = {"command": "/usr/sbin/pppd", "enabled": True, "args": ["yes", 2, None]}
        result = self.run_builder({"kind": "yaml", "value": value})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(yaml.safe_load(self.output.read_text()), value)

    def test_root_tree_keeps_manifest_and_relative_enablement(self):
        spec = {"kind": "tree", "files": {"etc/example": "/nix/store/example"},
                "links": {"etc/example-link": "example"}, "manifest": {"schema": 1}}
        result = self.run_builder(spec)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.readlink(self.output / "etc/example-link"), "example")
        self.assertEqual(json.loads((self.output / "manifest.json").read_text()), {"schema": 1})


if __name__ == "__main__":
    unittest.main()

"""CLI tests for the filesystem-only configuration tree builder."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

BUILDER = (
    Path(__file__).resolve().parents[1]
    / "pkgs/build-support/configuration-tree/builder.py"
)


class ConfigurationTreeTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.source = self.root / "input.json"
        self.output = self.root / "output"

    def manifest(self, files=None, links=None):
        return {
            "schema": 1,
            "kind": "configuration-tree",
            "files": {} if files is None else files,
            "links": {} if links is None else links,
            "services": {},
        }

    def run_cli(self, *arguments):
        return subprocess.run(
            [sys.executable, str(BUILDER), *map(str, arguments)],
            cwd=self.root,
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def build(self, manifest):
        self.source.write_text(json.dumps(manifest), encoding="utf-8")
        return self.run_cli(self.source, self.output)

    def assert_failure(self, result, message):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn(message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(os.path.lexists(self.output))

    def assert_links(self, links):
        for name, target in links.items():
            with self.subTest(name=name):
                destination = self.output / name
                self.assertTrue(destination.is_symlink())
                self.assertEqual(os.readlink(destination), target)

    def test_ppp_tree_and_complete_manifest(self):
        native = self.root / "native"
        native.mkdir()
        peer = native / "provider"
        peer.write_text("plugin pppoe.so\n", encoding="utf-8")
        secrets = native / "chap-secrets"
        secrets.write_text("user * secret\n", encoding="utf-8")
        hooks = native / "hooks"
        hooks.mkdir()
        (hooks / "ip-up").write_text("native hook\n", encoding="utf-8")
        manifest = self.manifest(
            files={
                "etc/ppp/peers/provider": str(peer),
                "etc/ppp/chap-secrets": str(secrets),
            },
            links={"etc/ppp/hooks": str(hooks)},
        )
        manifest["services"] = {
            "ppp-provider": {"command": ["/native/bin/pppd", "call", "provider"]}
        }
        manifest["description"] = "réseau PPP"

        result = self.build(manifest)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.stderr, "")
        self.assert_links({**manifest["files"], **manifest["links"]})
        written = self.output / "manifest.json"
        self.assertFalse(written.is_symlink())
        self.assertEqual(json.loads(written.read_text(encoding="utf-8")), manifest)
        self.assertEqual(
            written.read_bytes(),
            (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode("utf-8"),
        )
        self.assertEqual(
            sorted(
                str(path.relative_to(self.output)) for path in self.output.rglob("*")
            ),
            [
                "etc",
                "etc/ppp",
                "etc/ppp/chap-secrets",
                "etc/ppp/hooks",
                "etc/ppp/peers",
                "etc/ppp/peers/provider",
                "manifest.json",
            ],
        )

    def test_dangling_native_targets_and_relative_targets_are_not_inspected(self):
        manifest = self.manifest(
            files={"etc/ppp/options": "/nonexistent-native-store/generated/options"},
            links={
                "etc/ppp/hooks": "/nonexistent-native-store/hooks/",
                "etc/ppp/peers/provider": "../../native/missing-provider",
                "etc/ppp/manifest.json": "/nonexistent-native-store/manifest.json",
            },
        )
        result = self.build(manifest)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_links({**manifest["files"], **manifest["links"]})

    def test_empty_tree(self):
        manifest = self.manifest()
        result = self.build(manifest)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [path.name for path in self.output.iterdir()], ["manifest.json"]
        )
        self.assertEqual(
            json.loads((self.output / "manifest.json").read_text()), manifest
        )

    def test_identical_duplicate_targets_are_allowed_and_preserved(self):
        entries = {"etc/ppp/options": "/native/options"}
        manifest = self.manifest(files=entries, links=entries)
        result = self.build(manifest)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_links(entries)
        self.assertEqual(
            json.loads((self.output / "manifest.json").read_text()), manifest
        )

    def test_conflicting_duplicate_targets_are_rejected(self):
        result = self.build(
            self.manifest(
                files={"etc/ppp/options": "/native/one"},
                links={"etc/ppp/options": "/native/two"},
            )
        )
        self.assert_failure(result, "conflicting targets")

    def test_parent_link_collisions_are_rejected_before_creating_output(self):
        parent = {"etc/ppp": "/native/directory"}
        child = {"etc/ppp/options": "/native/options"}
        for files, links in (
            (parent, child),
            (child, parent),
            ({**child, **parent}, {}),
        ):
            with self.subTest(files=files, links=links):
                result = self.build(self.manifest(files=files, links=links))
                self.assert_failure(result, "parent link collision")

    def test_unsafe_destination_names_are_rejected(self):
        names = (
            "/etc/ppp/options",
            "",
            ".",
            "..",
            "./etc/ppp",
            "../outside",
            "etc/./ppp",
            "etc/../outside",
            "etc//ppp",
            "etc/ppp/",
            "etc/\0ppp",
        )
        for field in ("files", "links"):
            for name in names:
                with self.subTest(field=field, name=name):
                    manifest = self.manifest(files={"valid/link": "/native/valid"})
                    manifest[field][name] = "/native/target"
                    self.assert_failure(
                        self.build(manifest), "invalid relative output path"
                    )
        self.assertFalse((self.root / "outside").exists())

    def test_root_manifest_and_descendants_are_reserved(self):
        for field in ("files", "links"):
            for name in ("manifest.json", "manifest.json/child", "manifest.json/a/b"):
                with self.subTest(field=field, name=name):
                    manifest = self.manifest()
                    manifest[field][name] = "/native/target"
                    self.assert_failure(
                        self.build(manifest), "manifest.json is reserved"
                    )

    def test_manifest_must_be_an_object(self):
        for manifest in (None, [], "tree", 1, True):
            with self.subTest(manifest=manifest):
                self.assert_failure(
                    self.build(manifest), "manifest must be a JSON object"
                )

    def test_maps_must_be_objects(self):
        for field in ("files", "links"):
            for value in (None, [], "/native/target", 1, True):
                with self.subTest(field=field, value=value):
                    manifest = self.manifest()
                    manifest[field] = value
                    self.assert_failure(
                        self.build(manifest), f"{field!r} must be an object"
                    )
            with self.subTest(field=field, missing=True):
                manifest = self.manifest()
                del manifest[field]
                self.assert_failure(
                    self.build(manifest), f"{field!r} must be an object"
                )

    def test_targets_must_be_nonempty_strings_without_nul(self):
        for field in ("files", "links"):
            for target in (None, [], {}, 1, True, "", "/native/\0target"):
                with self.subTest(field=field, target=target):
                    manifest = self.manifest()
                    manifest[field]["etc/ppp/options"] = target
                    self.assert_failure(
                        self.build(manifest), "target for 'etc/ppp/options'"
                    )

    def test_malformed_json(self):
        for source in ("", "{", '{"files": {},}', "{} trailing-data"):
            with self.subTest(source=source):
                self.source.write_text(source, encoding="utf-8")
                self.assert_failure(
                    self.run_cli(self.source, self.output), "invalid JSON"
                )

    def test_excessively_nested_json_has_no_traceback(self):
        self.source.write_text("[" * 2000 + "]" * 2000, encoding="utf-8")
        self.assert_failure(
            self.run_cli(self.source, self.output), "configuration-tree:"
        )

    def test_invalid_utf8(self):
        self.source.write_bytes(b"\xff")
        self.assert_failure(self.run_cli(self.source, self.output), "utf-8")

    def test_invalid_metadata_is_rejected_before_creating_output(self):
        manifest = self.manifest()
        manifest["invalid"] = float("nan")
        self.assert_failure(self.build(manifest), "not JSON compliant")
        manifest["invalid"] = "\ud800"
        self.assert_failure(self.build(manifest), "utf-8")

    def test_missing_input_has_concise_os_error(self):
        self.assert_failure(self.run_cli(self.source, self.output), "No such file")

    def test_existing_output_is_not_modified(self):
        self.output.mkdir()
        sentinel = self.output / "keep"
        sentinel.write_text("unchanged", encoding="utf-8")
        result = self.build(self.manifest(files={"new": "/native/target"}))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("File exists", result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(list(self.output.iterdir()), [sentinel])
        self.assertEqual(sentinel.read_text(encoding="utf-8"), "unchanged")

    def test_cli_usage(self):
        for arguments in ((), (self.source,), (self.source, self.output, "extra")):
            with self.subTest(arguments=arguments):
                result = self.run_cli(*arguments)
                self.assertEqual(result.returncode, 2)
                self.assertIn("usage:", result.stderr)
                self.assertIn("MANIFEST_JSON OUTPUT", result.stderr)
                self.assertNotIn("Traceback", result.stderr)
                self.assertFalse(self.output.exists())
        help_result = self.run_cli("--help")
        self.assertEqual(help_result.returncode, 0)
        self.assertIn("MANIFEST_JSON OUTPUT", help_result.stdout)
        self.assertEqual(help_result.stderr, "")


if __name__ == "__main__":
    unittest.main()

"""Exercise startup without GitHub credentials, Docker, or writes outside a temp dir."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ENTRYPOINT = Path(__file__).resolve().parents[1] / "entrypoint.sh"


class EntrypointTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.runner = self.root / "runner"
        self.runner.mkdir()
        self.persist = self.root / "persist"
        self.started = self.root / "started"
        self.configured = self.runner / "configured"
        self.script = self.root / "entrypoint.sh"
        self.script.write_text(
            ENTRYPOINT.read_text().replace("/actions-runner", str(self.runner))
        )
        self.mocks = self.root / "mocks"
        self.mocks.mkdir()
        # Exercise the root startup branch regardless of the test user's UID.
        self.executable(self.mocks / "id", "echo 0\n")
        self.executable(
            self.runner / "config.sh",
            'touch configured\n'
            'if [[ ${CONFIG_EXIT:-0} != 0 ]]; then exit "$CONFIG_EXIT"; fi\n'
            'if [[ ${WRITE_CONFIG:-true} == true ]]; then\n'
            '  touch .runner .credentials\n'
            'fi\n',
        )

    @staticmethod
    def executable(path, body):
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def run_entrypoint(self, reuse=True, **extra):
        env = {
            "PATH": f"{self.mocks}:{os.defpath}",
            "REPO_URL": "https://github.com/example/repo",
            "RUNNER_TOKEN": "test-token",
            "RUNNER_NAME": "test-runner",
            "RUNNER_WORKDIR": str(self.root / "work"),
            "DISABLE_AUTOMATIC_DEREGISTRATION": "true",
        }
        if reuse:
            env["CONFIGURED_ACTIONS_RUNNER_FILES_DIR"] = str(self.persist)
        env.update(extra)
        return subprocess.run(
            ["bash", str(self.script), "touch", str(self.started)],
            cwd=self.runner, env=env, capture_output=True, text=True, timeout=5,
        )

    def test_failed_registration_stops_with_original_status(self):
        for reuse in (False, True):
            with self.subTest(reuse=reuse):
                result = self.run_entrypoint(reuse=reuse, CONFIG_EXIT="42")
                self.assertEqual(result.returncode, 42, result.stderr)
                self.assertIn("Runner configuration failed", result.stderr)
                self.assertFalse(self.started.exists())
                self.assertFalse(self.persist.exists())

    def test_success_without_runner_file_stops(self):
        result = self.run_entrypoint(WRITE_CONFIG="false")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("did not create .runner", result.stderr)
        self.assertFalse(self.started.exists())
        self.assertFalse(self.persist.exists())

    def test_first_registration_persists_without_optional_files(self):
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertTrue(self.started.exists())
        self.assertTrue((self.persist / ".runner").exists())
        self.assertTrue((self.persist / ".credentials").exists())

    def test_optional_files_are_preserved_when_present(self):
        (self.runner / "svc.sh").write_text("service script")
        (self.runner / "_diag").mkdir()
        (self.runner / "_diag" / "test.log").write_text("diagnostics")
        result = self.run_entrypoint()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.persist / "svc.sh").read_text(), "service script")
        self.assertTrue((self.persist / "_diag" / "test.log").exists())

    def test_existing_registration_skips_configuration(self):
        self.persist.mkdir()
        (self.persist / ".runner").write_text("existing registration")
        (self.persist / ".credentials").write_text("existing credentials")
        result = self.run_entrypoint(CONFIG_EXIT="42")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.configured.exists())
        self.assertTrue(self.started.exists())
        self.assertEqual(
            (self.runner / ".runner").read_text(), "existing registration"
        )

    def test_persistence_failure_prevents_start(self):
        self.persist.touch()
        result = self.run_entrypoint()
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.started.exists())

    def test_debug_mode_does_not_configure_persist_or_start(self):
        result = self.run_entrypoint(DEBUG_ONLY="true")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.configured.exists())
        self.assertFalse(self.persist.exists())
        self.assertFalse(self.started.exists())


if __name__ == "__main__":
    unittest.main()

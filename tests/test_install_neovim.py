"""Offline installer tests; fixture archives are not real Neovim builds."""

import hashlib
import io
import os
import shutil
import subprocess
import tarfile
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]


class InstallNeovimTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="nvim installer ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.repo = self.root / "config checkout"
        (self.repo / "scripts").mkdir(parents=True)
        shutil.copy2(REPO / "scripts/install-neovim.sh", self.repo / "scripts")
        self.version = "0.12.6"
        (self.repo / ".neovim-version").write_text(self.version + "\n")
        self.archive_name = "nvim-linux-x86_64.tar.gz"
        self.archive = self.root / self.archive_name
        self.make_archive()
        self.write_checksum()
        self.home = self.root / "home with spaces"
        self.home.mkdir()
        self.shims = self.root / "shims"
        self.shims.mkdir()
        self.make_executable("uname", '#!/bin/sh\ncase "$1" in -s) echo "${TEST_OS:-Linux}";; -m) echo "${TEST_ARCH:-x86_64}";; esac\n')
        self.make_executable("curl", '''#!/bin/sh
printf '%s\\n' "$*" >> "$TEST_REQUESTS"
[ "${TEST_CURL_FAIL:-0}" = 0 ] || exit 22
while [ "$#" -gt 0 ]; do
    if [ "$1" = --output ]; then cp "$TEST_ARCHIVE" "$2"; exit; fi
    shift
done
exit 64
''')
        self.env = dict(os.environ, HOME=str(self.home), PATH=str(self.shims) + os.pathsep + os.environ["PATH"],
                        TEST_ARCHIVE=str(self.archive), TEST_REQUESTS=str(self.root / "requests"))
        self.target = self.home / ".local/opt" / f"nvim-v{self.version}-linux-x86_64"
        self.link = self.home / ".local/bin/nvim"

    def make_executable(self, name, contents):
        path = self.shims / name
        path.write_text(contents)
        path.chmod(0o755)

    def make_archive(self, version=None, include_binary=True):
        with tarfile.open(self.archive, "w:gz") as archive:
            if include_binary:
                contents = f"#!/bin/sh\nprintf 'NVIM v{version or self.version}\\nfixture only\\n'\n".encode()
                info = tarfile.TarInfo("nvim-linux-x86_64/bin/nvim")
                info.mode, info.size = 0o755, len(contents)
                archive.addfile(info, io.BytesIO(contents))
            else:
                info = tarfile.TarInfo("nvim-linux-x86_64/README")
                info.size = 0
                archive.addfile(info, io.BytesIO())

    def write_checksum(self):
        digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        (self.repo / "neovim-sha256.txt").write_text(f"{digest}  {self.archive_name}\n")

    def run_installer(self, **env):
        return subprocess.run(["bash", str(self.repo / "scripts/install-neovim.sh")],
                              check=False, env=dict(self.env, **env), text=True, capture_output=True, timeout=20)

    def assert_failure_without_install(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.link.exists())
        self.assertFalse(self.target.exists())
        self.assertEqual(list((self.home / ".local/opt").glob(".nvim-install.*")), [])

    def test_installs_verified_archive_into_versioned_path_with_spaces(self):
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.link.resolve(), self.target / "bin/nvim")
        self.assertEqual(subprocess.check_output([str(self.link), "--version"], text=True).splitlines()[0], "NVIM v0.12.6")
        request = (self.root / "requests").read_text()
        self.assertIn("https://github.com/neovim/neovim/releases/download/v0.12.6/" + self.archive_name, request)
        self.assertIn("--proto =https", request)
        self.assertEqual(list((self.home / ".local/opt").glob(".nvim-install.*")), [])

    def test_second_install_is_idempotent_and_needs_no_network(self):
        self.assertEqual(self.run_installer().returncode, 0)
        result = self.run_installer(TEST_CURL_FAIL="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len((self.root / "requests").read_text().splitlines()), 1)

    def test_rejects_checksum_mismatch_before_extracting(self):
        self.archive.write_bytes(self.archive.read_bytes() + b"tampered")
        result = self.run_installer()
        self.assert_failure_without_install(result)
        self.assertIn("checksum", result.stderr.lower())

    def test_rejects_download_failure_and_cleans_staging(self):
        self.assert_failure_without_install(self.run_installer(TEST_CURL_FAIL="1"))

    def test_rejects_wrong_binary_version(self):
        self.make_archive(version="0.13.0")
        self.write_checksum()
        self.assert_failure_without_install(self.run_installer())

    def test_rejects_archive_without_binary(self):
        self.make_archive(include_binary=False)
        self.write_checksum()
        self.assert_failure_without_install(self.run_installer())

    def test_refuses_to_overwrite_regular_user_executable(self):
        self.link.parent.mkdir(parents=True)
        self.link.write_text("keep me\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.link.read_text(), "keep me\n")
        self.assertFalse((self.root / "requests").exists())

    def test_refuses_to_reuse_unverified_existing_target(self):
        self.target.mkdir(parents=True)
        (self.target / "keep").write_text("existing\n")
        result = self.run_installer()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual((self.target / "keep").read_text(), "existing\n")
        self.assertFalse(self.link.exists())

    def test_switches_existing_symlink_without_removing_old_install(self):
        old = self.root / "old nvim"
        old.write_text("keep old version\n")
        self.link.parent.mkdir(parents=True)
        self.link.symlink_to(old)
        result = self.run_installer()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(old.read_text(), "keep old version\n")
        self.assertEqual(self.link.resolve(), self.target / "bin/nvim")

    def test_rejects_unsupported_architecture_and_os_before_download(self):
        for overrides in ({"TEST_ARCH": "riscv64"}, {"TEST_OS": "Darwin"}):
            with self.subTest(overrides=overrides):
                self.assert_failure_without_install(self.run_installer(**overrides))
        self.assertFalse((self.root / "requests").exists())

    def test_rejects_invalid_version_and_digest(self):
        (self.repo / ".neovim-version").write_text("nightly\n")
        self.assert_failure_without_install(self.run_installer())
        (self.repo / ".neovim-version").write_text(self.version + "\n")
        (self.repo / "neovim-sha256.txt").write_text("not-a-digest  " + self.archive_name + "\n")
        self.assert_failure_without_install(self.run_installer())
        self.assertFalse((self.root / "requests").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

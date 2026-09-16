import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


MODULE_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = MODULE_ROOT / "scripts" / "build_package.py"


def load_builder():
    spec = importlib.util.spec_from_file_location("build_package", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class BuildPackageTests(unittest.TestCase):
    def test_archive_has_sorted_python_sources_at_root_with_fixed_timestamps(self):
        builder = load_builder()
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_dir = Path(temporary_directory) / "src"
            source_dir.mkdir()
            (source_dir / "zeta.py").write_text("zeta = 1\n", encoding="utf-8")
            (source_dir / "alpha.py").write_text("alpha = 1\n", encoding="utf-8")
            (source_dir / "notes.txt").write_text("ignored\n", encoding="utf-8")

            archive = builder.build_archive_bytes(source_dir)

        with zipfile.ZipFile(io.BytesIO(archive)) as package:
            self.assertEqual(package.namelist(), ["alpha.py", "zeta.py"])
            self.assertEqual(
                [info.date_time for info in package.infolist()],
                [(1980, 1, 1, 0, 0, 0), (1980, 1, 1, 0, 0, 0)],
            )
            self.assertEqual(package.read("alpha.py"), b"alpha = 1\n")

    def test_archive_bytes_are_stable_when_source_metadata_changes(self):
        builder = load_builder()
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_dir = Path(temporary_directory) / "src"
            source_dir.mkdir()
            source = source_dir / "module.py"
            source.write_text("value = 1\n", encoding="utf-8")
            first = builder.build_archive_bytes(source_dir)
            source.touch()
            second = builder.build_archive_bytes(source_dir)

        self.assertEqual(first, second)

    def test_check_reports_clean_and_drifted_packages(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            package_path = Path(temporary_directory) / "account-kpi-export-lambda.zip"
            source_dir = Path(temporary_directory) / "src"
            source_dir.mkdir()
            (source_dir / "module.py").write_text("value = 1\n", encoding="utf-8")

            build = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--source-dir",
                    str(source_dir),
                    "--output",
                    str(package_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(build.returncode, 0, build.stderr)

            clean = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--check",
                    "--source-dir",
                    str(source_dir),
                    "--output",
                    str(package_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(clean.returncode, 0, clean.stderr)

            package_path.write_bytes(b"drift")
            drifted = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--check",
                    "--source-dir",
                    str(source_dir),
                    "--output",
                    str(package_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )

        self.assertNotEqual(drifted.returncode, 0)
        self.assertIn("drift", drifted.stderr.lower())


if __name__ == "__main__":
    unittest.main()

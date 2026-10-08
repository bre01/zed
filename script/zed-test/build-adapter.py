#!/usr/bin/env python3
"""Build the pinned Codex ACP adapter; optionally install its launcher."""

import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile


def run(*arguments, directory):
    subprocess.run(arguments, cwd=directory, check=True)


def install_file(source, destination):
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as temporary:
        temporary_path = Path(temporary.name)
    try:
        shutil.copy2(source, temporary_path)
        os.replace(temporary_path, destination)
    finally:
        temporary_path.unlink(missing_ok=True)


def main():
    repository = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, default=repository / "target/zed-test-codex-acp")
    parser.add_argument("--install", action="store_true")
    parser.add_argument("--install-dir", type=Path, default=Path.home() / ".local/share/zed-test/codex-acp")
    arguments = parser.parse_args()
    integration = repository / "integration/codex-acp"
    metadata = json.loads((integration / "base.json").read_text())
    patch = integration / metadata["patch"]
    work_directory = arguments.work_dir.expanduser().resolve()
    work_directory.mkdir(parents=True, exist_ok=True)

    if not (work_directory / ".git").exists():
        if any(work_directory.iterdir()):
            parser.error(f"Work directory must be empty: {work_directory}")
        run("git", "init", directory=work_directory)
        run("git", "remote", "add", "origin", metadata["repository"], directory=work_directory)
        run("git", "fetch", "--depth=1", "origin", metadata["commit"], directory=work_directory)
        run("git", "checkout", "--detach", "FETCH_HEAD", directory=work_directory)

    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=work_directory, text=True).strip()
    if head != metadata["commit"]:
        parser.error(f"Expected pinned adapter commit {metadata['commit']}, found {head}")
    applied = subprocess.run(
        ["git", "apply", "--reverse", "--check", str(patch)],
        cwd=work_directory, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0
    if not applied:
        status = subprocess.check_output(["git", "status", "--porcelain"], cwd=work_directory, text=True)
        if status.strip():
            parser.error("Adapter checkout has local changes; choose another --work-dir")
        run("git", "apply", "--check", str(patch), directory=work_directory)
        run("git", "apply", str(patch), directory=work_directory)

    run("npm", "ci", directory=work_directory)
    run("npm", "run", "typecheck", directory=work_directory)
    run("npm", "run", "build", directory=work_directory)
    print(f"Built adapter: {work_directory / 'dist/index.js'}")
    if not arguments.install:
        return

    node = shutil.which("node")
    codex = os.environ.get("CODEX_PATH") or shutil.which("codex")
    if not node or not codex:
        parser.error("Installation requires node and codex on PATH, or CODEX_PATH pointing to Codex")
    destination = arguments.install_dir.expanduser().resolve()
    install_file(work_directory / "dist/index.js", destination / "index.mjs")
    install_file(work_directory / "LICENSE", destination / "LICENSE")
    launcher = destination / "run"
    launcher.write_text(
        "#!/bin/sh\nset -eu\n"
        f"if [ -z \"${{CODEX_PATH:-}}\" ]; then export CODEX_PATH={shlex.quote(codex)}; fi\n"
        "export WS_NO_BUFFER_UTIL=1\nexport WS_NO_UTF_8_VALIDATE=1\n"
        f"exec {shlex.quote(node)} {shlex.quote(str(destination / 'index.mjs'))} \"$@\"\n"
    )
    launcher.chmod(0o755)
    print(f"Installed launcher: {launcher}")
    print("Connect Zed to this launcher. The Codex daemon must already be running.")


if __name__ == "__main__":
    main()

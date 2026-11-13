#!/usr/bin/env python3
"""Build a local review archive from an explicit public-file allowlist."""

import hashlib
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main():
    subprocess.run([sys.executable, str(ROOT / "scripts" / "check-docs.py")],
                   check=True)
    files = [ROOT / "README.md", ROOT / ".env.template", ROOT / ".gitignore"]
    for folder, extensions in {
        "docs": {".md", ".png"},
        "samples": {".md"},
        "scripts": {".py", ".sh", ".ps1"},
        "deploy": {".json", ".bicep"},
    }.items():
        files.extend(path for path in (ROOT / folder).rglob("*")
                     if path.is_file() and path.suffix in extensions
                     and not any(part.startswith(".") for part in path.relative_to(ROOT).parts)
                     and ".local." not in path.name)
    files = sorted(set(files))
    for path in files:
        if path.is_symlink() or not path.resolve().is_relative_to(ROOT):
            raise ValueError(f"Refusing non-repository file: {path.name}")
    destination = ROOT / "dist" / "atlas-foundry-source.zip"
    destination.parent.mkdir(exist_ok=True)
    manifest = []
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            name = path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            archive.writestr(name, data)
            manifest.append(f"{hashlib.sha256(data).hexdigest()}  {name}")
        archive.writestr("SHA256SUMS.txt", "\n".join(manifest) + "\n")
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise ValueError("Archive integrity check failed")
        if ".env" in archive.namelist() or any(".git/" in n for n in archive.namelist()):
            raise ValueError("Private configuration found in archive")
    print(f"Built {destination.relative_to(ROOT)}: {len(files)} public files plus SHA256SUMS.txt")
    print("Local archive only; nothing uploaded or published.")


if __name__ == "__main__":
    main()

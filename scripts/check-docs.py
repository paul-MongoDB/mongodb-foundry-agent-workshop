#!/usr/bin/env python3
"""Check local documentation links, copyable examples, and screenshot assets."""

import json
import re
import struct
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]


def anchors(text):
    return {
        re.sub(r"[^\w\- ]", "", heading.lower()).strip().replace(" ", "-")
        for heading in re.findall(r"^#{1,6}\s+(.+)$", text, re.MULTILINE)
    }


def main():
    documents = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md")),
                 *sorted((ROOT / "samples").rglob("*.md"))]
    errors = []
    links = examples = bash_examples = 0
    for path in documents:
        text = path.read_text()
        label = str(path.relative_to(ROOT))
        language = None
        body = []
        for number, line in enumerate(text.splitlines(), 1):
            if line.rstrip() != line:
                errors.append(f"{label}:{number}: trailing whitespace")
            fence = re.fullmatch(r"\s*```(\w*)\s*", line)
            if fence:
                if language is None:
                    language, body = fence[1], []
                else:
                    try:
                        if language == "json":
                            json.loads("\n".join(body))
                            examples += 1
                        elif language == "bash":
                            subprocess.run(["bash", "-n"], input="\n".join(body),
                                           text=True, capture_output=True, check=True)
                            bash_examples += 1
                    except (ValueError, subprocess.CalledProcessError) as error:
                        errors.append(f"{label}:{number}: invalid {language} example: {error}")
                    language = None
            elif language is not None:
                body.append(line)
        if language is not None:
            errors.append(f"{label}: unclosed code fence")

        for target in re.findall(r"!?\[[^\]]*\]\(([^\n]+?)\)", text):
            target = unquote(target.strip().strip("<>"))
            if urlsplit(target).scheme:
                continue
            filename, _, fragment = target.partition("#")
            destination = (path.parent / filename).resolve() if filename else path
            links += 1
            if not destination.is_relative_to(ROOT):
                errors.append(f"{label}: link escapes repository: {target}")
            elif not destination.exists():
                errors.append(f"{label}: missing target: {target}")
            elif fragment and destination.suffix == ".md":
                if fragment not in anchors(destination.read_text()):
                    errors.append(f"{label}: missing anchor: {target}")

    images = sorted((ROOT / "docs" / "images").glob("*.png"))
    for path in images:
        data = path.read_bytes()
        label = str(path.relative_to(ROOT))
        if data[:8] != b"\x89PNG\r\n\x1a\n":
            errors.append(f"{label}: not PNG data")
            continue
        width, height = struct.unpack(">II", data[16:24])
        if not 0 < width <= 1600 or height <= 0:
            errors.append(f"{label}: unexpected image dimensions")
        offset = 8
        while offset < len(data):
            length = struct.unpack(">I", data[offset:offset + 4])[0]
            kind = data[offset + 4:offset + 8]
            if kind in (b"eXIf", b"tEXt", b"zTXt", b"iTXt"):
                errors.append(f"{label}: embedded metadata must be removed")
            offset += length + 12

    prompt = (ROOT / "docs" / "agent-instructions.md").read_text()
    expected = {"<ATLAS_PROJECT_NAME>", "<ATLAS_PROJECT_ID>", "<ATLAS_CLUSTER_NAME>"}
    if set(re.findall(r"<ATLAS_[A-Z_]+>", prompt)) != expected:
        errors.append("Agent prompt must contain the three expected Atlas placeholders")

    if errors:
        print("\n".join(errors))
        return 1
    print(f"PASS: {len(documents)} Markdown files, {links} local links/anchors, "
          f"{examples} JSON examples, {bash_examples} Bash examples, {len(images)} PNGs; "
          "prompt placeholders checked.")
    print("Visual screenshot review and live platform validation remain separate checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

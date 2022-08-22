#!/usr/bin/env python
import sys
import pathlib
import subprocess

THIS_FILE = pathlib.Path(__file__).resolve()
CODE_ROOT = THIS_FILE.parent.parent.parent.parent
README_PATH = CODE_ROOT / "README.rst"


def main(version, sha256sum):
    in_contents = README_PATH.read_text()
    if version in in_contents:
        print(f"README file already contains an entry for version {version}")
        sys.exit(1)
    out_contents = ""
    found_anchor = False
    updated_version = False
    if version not in in_contents:
        for line in in_contents.splitlines(True):
            if updated_version:
                out_contents += line
                continue
            if found_anchor:
                if not line.startswith("-"):
                    out_contents += line
                    continue
                out_contents += "- {}: ``{}``\n".format(version, sha256sum)
                out_contents += line
                updated_version = True
                continue

            out_contents += line
            if line.startswith(".. _sha256sums:"):
                found_anchor = True
    if in_contents != out_contents:
        README_PATH.write_text(out_contents)

    ret = subprocess.run(
        ["git", "diff", "--stat"], universal_newlines=True, capture_output=True
    )
    if "1 file changed, 1 insertion(+)" not in ret.stdout:
        print("Too Many Changes to the readme file")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])

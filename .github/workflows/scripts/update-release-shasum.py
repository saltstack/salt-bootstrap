#!/usr/bin/env python
import sys
import pathlib

THIS_FILE = pathlib.Path(__file__).resolve()
CODE_ROOT = THIS_FILE.parent.parent.parent.parent
README_PATH = CODE_ROOT / "README.rst"


def main(version, sha256sum):
    in_contents = README_PATH.read_text()
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


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])

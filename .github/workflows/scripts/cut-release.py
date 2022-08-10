#!/usr/bin/env python
import os
import re
import sys
import pathlib
import argparse
import requests
from datetime import datetime

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent.parent.parent


class ClassPropertyDescriptor:
    def __init__(self, fget, fset=None):
        self.fget = fget
        self.fset = fset

    def __get__(self, obj, klass=None):
        if klass is None:
            klass = type(obj)
        return self.fget.__get__(obj, klass)()

    def __set__(self, obj, value):
        if not self.fset:
            raise AttributeError("can't set attribute")
        type_ = type(obj)
        return self.fset.__get__(obj, type_)(value)

    def setter(self, func):
        if not isinstance(func, (classmethod, staticmethod)):
            func = classmethod(func)
        self.fset = func
        return self


def classproperty(func):
    if not isinstance(func, (classmethod, staticmethod)):
        func = classmethod(func)

    return ClassPropertyDescriptor(func)


class Session:

    _instance = None

    def __init__(self, endpoint=None):
        if endpoint is None:
            endpoint = "https://api.github.com"
        self.endpoint = endpoint
        self.session = requests.Session()
        self.session.headers.update(
            {
                "Accept": "application/vnd.github+json",
                "Authorization": f"token {os.environ['GITHUB_TOKEN']}",
            }
        )

    @classproperty
    def instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def get(self, path, **kwargs):
        return self.session.get(f"{self.endpoint}/{path.lstrip('/')}", **kwargs)

    def post(self, path, **kwargs):
        return self.session.post(f"{self.endpoint}/{path.lstrip('/')}", **kwargs)

    def __enter__(self):
        self.session.__enter__()
        return self

    def __exit__(self, *args):
        self.session.__exit__(*args)


def get_latest_release(options):
    response = Session.instance.get(f"/repos/{options.repo}/releases/latest")
    if response.status_code != 404:
        return response.json()["tag_name"]

    print(
        f"Failed to get latest release. HTTP Response:\n{response.text}",
        file=sys.stderr,
        flush=True,
    )
    print("Searching tags...", file=sys.stderr, flush=True)

    tags = []
    page = 0
    while True:
        page += 1
        response = Session.instance.get(
            f"/repos/{options.repo}/tags", data={"pre_page": 100, "page": page}
        )
        repo_tags = response.json()
        added_tags = False
        for tag in repo_tags:
            if tag["name"] not in tags:
                tags.append(tag["name"])
                added_tags = True
        if added_tags is False:
            break

    return list(sorted(tags))[-1]


def get_generated_changelog(options):
    response = Session.instance.post(
        f"/repos/{options.repo}/releases/generate-notes",
        json={
            "tag_name": options.release_tag,
            "previous_tag_name": options.previous_tag,
            "target_commitish": "develop",
        },
    )
    if response.status_code == 200:
        return response.json()
    return response.text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", required=True, help="The <user>/<repo> to use")
    parser.add_argument("--release-tag", required=False, help="The tag of the release")
    parser.add_argument(
        "--previous-tag",
        required=False,
        help="The previous release tag. If not passed, the GH Api will be queried for it.",
    )

    changelog_file = REPO_ROOT / "CHANGELOG.md"

    if not os.environ.get("GITHUB_TOKEN"):
        parser.exit(status=1, message="GITHUB_TOKEN environment variable not set")

    options = parser.parse_args()
    if not options.release_tag:
        options.release_tag = f"v{datetime.utcnow().strftime('%Y.%m.%d')}"
    if not options.previous_tag:
        options.previous_tag = get_latest_release(options)

    print(
        f"Creating changelog entries from {options.previous_tag} to {options.release_tag} ...",
        file=sys.stderr,
        flush=True,
    )

    changelog = get_generated_changelog(options)
    if not isinstance(changelog, dict):
        parser.exit(
            status=1,
            message=f"Unable to generate changelog. HTTP Response:\n{changelog}",
        )

    cut_release_version = REPO_ROOT / ".cut_release_version"
    print(
        f"* Writing {cut_release_version.relative_to(REPO_ROOT)} ...",
        file=sys.stderr,
        flush=True,
    )
    cut_release_version.write_text(options.release_tag)

    cut_release_changes = REPO_ROOT / ".cut_release_changes"
    print(
        f"* Writing {cut_release_changes.relative_to(REPO_ROOT)} ...",
        file=sys.stderr,
        flush=True,
    )
    cut_release_changes.write_text(changelog["body"])

    print(
        f"* Updating {changelog_file.relative_to(REPO_ROOT)} ...",
        file=sys.stderr,
        flush=True,
    )
    changelog_file.write_text(
        f"# {changelog['name']}\n\n"
        + changelog["body"]
        + "\n\n"
        + changelog_file.read_text()
    )

    bootstrap_script_path = REPO_ROOT / "bootstrap-salt.sh"
    print(
        f"* Updating {bootstrap_script_path.relative_to(REPO_ROOT)} ...",
        file=sys.stderr,
        flush=True,
    )
    bootstrap_script_path.write_text(
        re.sub(
            r'__ScriptVersion="(.*)"',
            f'__ScriptVersion="{options.release_tag.lstrip("v")}"',
            bootstrap_script_path.read_text(),
        )
    )
    parser.exit(status=0, message="CHANGELOG.md and bootstrap-salt.sh updated\n")


if __name__ == "__main__":
    main()

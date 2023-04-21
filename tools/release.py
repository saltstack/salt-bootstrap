"""
These commands are used to release Salt Bootstrap.
"""
# pylint: disable=resource-leakage,broad-except,3rd-party-module-not-gated
from __future__ import annotations

import logging
import os
import pathlib
import sys
from typing import TYPE_CHECKING

from ptscripts import command_group
from ptscripts import Context

import tools.utils

try:
    import boto3
except ImportError:
    print(
        "\nPlease run 'python -m pip install -r requirements/release.txt'\n",
        file=sys.stderr,
        flush=True,
    )
    raise

log = logging.getLogger(__name__)

# Define the command group
release = command_group(
    name="release",
    help="Release Related Commands",
    description=__doc__,
)


@release.command(
    name="s3-publish",
    arguments={
        "branch": {
            "help": "The kind of publish to do.",
            "choices": ("stable", "develop"),
        },
        "key_id": {
            "help": "The GnuPG key ID used to sign.",
            "required": True,
        },
    },
)
def s3_publish(ctx: Context, branch: str, key_id: str = None):
    """
    Publish scripts to S3.
    """
    if TYPE_CHECKING:
        assert key_id

    ctx.info("Preparing upload ...")
    s3 = boto3.client("s3")

    ctx.info(
        f"Uploading release artifacts to {tools.utils.RELEASE_BUCKET_NAME!r} bucket ..."
    )
    upload_files = {
        "stable": {
            f"{tools.utils.GPG_KEY_FILENAME}.gpg": [
                f"bootstrap/stable/{tools.utils.GPG_KEY_FILENAME}.gpg",
            ],
            f"{tools.utils.GPG_KEY_FILENAME}.pub": [
                f"bootstrap/stable/{tools.utils.GPG_KEY_FILENAME}.pub",
            ],
            "bootstrap-salt.sh": [
                "bootstrap/stable/bootstrap-salt.sh",
            ],
            "bootstrap-salt.sh.sha256": [
                "bootstrap/stable/bootstrap-salt.sh.sha256",
                "bootstrap/stable/bootstrap/sha256",
            ],
            "bootstrap-salt.ps1": [
                "bootstrap/stable/bootstrap-salt.ps1",
            ],
            "bootstrap-salt.ps1.sha256": [
                "bootstrap/stable/bootstrap-salt.ps1.sha256",
                "bootstrap/stable/winbootstrap/sha256",
            ],
        },
        "develop": {
            f"{tools.utils.GPG_KEY_FILENAME}.gpg": [
                f"bootstrap/develop/{tools.utils.GPG_KEY_FILENAME}.gpg",
            ],
            f"{tools.utils.GPG_KEY_FILENAME}.pub": [
                f"bootstrap/develop/{tools.utils.GPG_KEY_FILENAME}.pub",
            ],
            "bootstrap-salt.sh": [
                "bootstrap/develop/bootstrap-salt.sh",
                "bootstrap/develop/bootstrap/develop",
            ],
            "bootstrap-salt.sh.sha256": [
                "bootstrap/develop/bootstrap-salt.sh.sha256",
            ],
            "bootstrap-salt.ps1": [
                "bootstrap/develop/bootstrap-salt.ps1",
                "bootstrap/develop/winbootstrap/develop",
            ],
            "bootstrap-salt.ps1.sha256": [
                "bootstrap/develop/bootstrap-salt.ps1.sha256",
            ],
        },
    }

    files_to_upload: list[tuple[str, str]] = []

    try:
        # Export the GPG key in use
        tools.utils.export_gpg_key(ctx, key_id, tools.utils.REPO_ROOT)
        for lpath, rpaths in upload_files[branch].items():
            ctx.info(f"Processing {lpath} ...")
            if lpath.endswith(".sha256") and not os.path.exists(lpath):
                ret = ctx.run(
                    "sha256sum",
                    lpath.replace(".sha256", ""),
                    capture=True,
                    check=False,
                )
                if ret.returncode:
                    ctx.error(f"Failed to get the sha256sum of {lpath}")
                    ctx.exit(1)
                pathlib.Path(lpath).write_bytes(ret.stdout)
            for rpath in rpaths:
                files_to_upload.append((lpath, rpath))
            if not lpath.endswith((".gpg", ".pub")):
                tools.utils.gpg_sign(ctx, key_id, pathlib.Path(lpath))
                files_to_upload.append((f"{lpath}.asc", f"{rpaths[0]}.asc"))

        for lpath, rpath in sorted(files_to_upload):
            size = pathlib.Path(lpath).stat().st_size
            ctx.info(f" Uploading {lpath} -> {rpath}")
            with tools.utils.create_progress_bar(file_progress=True) as progress:
                task = progress.add_task(description="Uploading...", total=size)
                s3.upload_file(
                    lpath,
                    tools.utils.RELEASE_BUCKET_NAME,
                    rpath,
                    Callback=tools.utils.UpdateProgress(progress, task),
                )
    except KeyboardInterrupt:
        pass

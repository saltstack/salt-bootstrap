"""
These commands are used to release Salt Bootstrap.
"""
# pylint: disable=resource-leakage,broad-except,3rd-party-module-not-gated
from __future__ import annotations

import logging
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
    paths_to_upload = [
        f"{tools.utils.GPG_KEY_FILENAME}.gpg",
        f"{tools.utils.GPG_KEY_FILENAME}.pub",
    ]
    copy_exclusions = [
        ".asc",
        ".gpg",
        ".pub",
        ".sha256",
    ]

    try:
        # Export the GPG key in use
        tools.utils.export_gpg_key(ctx, key_id, tools.utils.REPO_ROOT)

        for fpath in tools.utils.REPO_ROOT.glob("bootstrap-salt.*"):
            if fpath.suffix in copy_exclusions:
                continue
            paths_to_upload.append(fpath.name)
            ret = ctx.run(
                "sha256sum",
                fpath.relative_to(tools.utils.REPO_ROOT),
                capture=True,
                check=False,
            )
            if ret.returncode:
                ctx.error(
                    f"Failed to get the sha256sum of {fpath.relative_to(tools.utils.REPO_ROOT)}"
                )
                ctx.exit(1)
            shasum_file = fpath.parent / f"{fpath.name}.sha256"
            shasum_file.write_bytes(ret.stdout)
            paths_to_upload.append(shasum_file.name)
            tools.utils.gpg_sign(ctx, key_id, shasum_file)
            paths_to_upload.append(f"{shasum_file.name}.asc")
            tools.utils.gpg_sign(ctx, key_id, fpath)
            paths_to_upload.append(f"{fpath.name}.asc")

        for path in paths_to_upload:
            upload_path = f"bootstrap/{branch}/{path}"
            size = fpath.stat().st_size
            ctx.info(f"  {upload_path}")
            with tools.utils.create_progress_bar(file_progress=True) as progress:
                task = progress.add_task(description="Uploading...", total=size)
                s3.upload_file(
                    fpath,
                    tools.utils.RELEASE_BUCKET_NAME,
                    upload_path,
                    Callback=tools.utils.UpdateProgress(progress, task),
                )
    except KeyboardInterrupt:
        pass

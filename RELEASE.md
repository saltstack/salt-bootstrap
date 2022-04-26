[#](#) Release process

- See if there are any PRs worth squeezing into release.
- Go through the changes since last release, add them to changelog.
- Add any new authors to the AUTHORS file.
- If there's a new Salt release(major), update the script to add support for it.
- Bump version for release.
- Open PR against develop with these changes.
- Once the above PR is merged, open a PR against stable with the changes from develop.
- Once the above PR is merged, wait until an automatic PR is opened against stable which updates the checksums.
- Once the above PR is merged, tag the release `v{version-here}` and push the tag.
- Wait until an automatic PR is opened against the develop branch updating the checksums in `README.rst`. Merge it.
- Check that an automated PR was opened against the salt repo updating the bootstrap script, located in `salt/cloud/deploy/bootstrap-salt.sh`

- Victory!

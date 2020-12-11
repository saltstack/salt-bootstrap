# Release process

- See if there are any PRs worth squeezing into release.
- Go through the changes since last release, add them to changelog.
- Add any new authors to the AUTHORS file.
- If there's a new Salt release(major), update the script to add support for it.
- Bump version for release
- Open PR against develop with these changes.
- Once the above PR is merged, open a PR against master with the changes from develop
- Open a PR against salt with the new stable release.
- Open a PR against kitchen-salt with the new stable release.

# Release process

- See if there are any PRs worth squeezing into release.
- Go through the changes since last release, add them to changelog.
- Add any new authors to the AUTHORS file.
- Bump version for release
- Open PR against develop with these changes.
- Once the above PR is merged, open a PR against master with the changes from develop
- Add a commit on that PR for updating the .sha256 files
- Once the PR against master is merged, update shasums on README on the develop branch
- Open a PR against salt with the new stable release.
- Open a PR against kitchen-salt with the new stable release.

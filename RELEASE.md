[#](#) Release process

- See if there are any PRs worth squeezing into release.
- Go through the changes since last release, add them to changelog.
- Add any new authors to the AUTHORS file.
- If there's a new Salt release (major), update the script to add support for it.
- Bump version for release.
- Open PR against develop with these changes.
- Once the above PR is merged, go to [Cut Release](https://github.com/saltstack/salt-bootstrap/actions/workflows/release.yml) and `Run workflow` against `develop` branch
- Open a new PR against the branch of the oldest supported version of [the salt repo](https://github.com/saltstack/salt) (ex. `3006.x`), and replace `salt/cloud/deploy/bootstrap-salt.sh` with the latest `bootstrap-salt.sh` file
- When that PR is merged into [the salt repo](https://github.com/saltstack/salt), merge-forwards into the latest branches and `master` will ensure that the latest bootstrap script is available
- Victory!

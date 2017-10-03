# Contributing Guidelines

## License Notice

The Salt Bootstrap project is open and encouraging to code contributions. Please be
advised that all code contributions will be licensed under the Apache 2.0 License.
We cannot accept contributions that already hold a License other than Apache 2.0
without explicit exception.

## Reporting Issues

The Salt Bootstrap issue tracker is used for feature requests and bug reports.

### Bugs

A bug is a *demonstrable problem* that is caused by the code in the repository.

Please read the following guidelines before you 
[file an issue](https://github.com/saltstack/salt-bootstrap/issues/new).

1. **Use the GitHub issue search** -- check if the issue has
   already been reported. If it has been, please comment on the existing issue.

2. **Check if the issue has been fixed** -- If you found a possible problem, or bug,
   please try to bootstrap using the bootstrap scirpt from the develop branch. The
   issue you are having might have already been fixed and it's just not yet included
   in the stable release.
    
    ```
    curl -o bootstrap-salt.sh -L https://raw.githubusercontent.com/saltstack/salt-bootstrap/develop/bootstrap-salt.sh
    sudo sh bootstrap-salt.sh git develop
    ```

3. **Isolate the demonstrable problem** -- make sure that the
   code in the project's repository is *definitely* responsible for the issue.

4. **Include a reproducible example** -- Provide the steps which
   led you to the problem.

Please try to be as detailed as possible in your report. What is your
environment? What steps will reproduce the issue? What operating system? What
would you expect to be the outcome? All these details will help people to
assess and fix any potential bugs.

**Including the version and system information will always help,** such as:

- Output of `salt --versions-report`
- Output of `bootstrap-salt.sh -v`
- System type
- Cloud/VM provider as appropriate

Valid bugs will worked on as quickly as resources can be reasonably allocated.

### Features

Feature additions and requests are welcomed. When requesting a feature it will
be placed under the `Feature` label.

If a new feature is desired, the fastest way to get it into Salt Bootstrap is
to contribute the code. Before starting on a new feature, an issue should be
filed for it. The one requesting the feature will be able to then discuss the
feature with the Salt Bootstrap maintainers and discover the best way to get
the feature included into the bootstrap script and if the feature makes sense.

It is possible that the desired feature has already been completed.
Look for it in the [README](https://github.com/saltstack/salt-bootstrap/blob/develop/README.rst)
or exploring the wide list of options detailed at the top of the script. These
options are also available by running the `-h` help option for the script. It
is also common that the problem which would be solved by the new feature can be
easily solved another way, which is a great reason to ask first.

## Fixing Issues

Fixes for issues are very welcome!

Once you've fixed the issue you have in hand, create a 
[pull request](https://help.github.com/articles/creating-a-pull-request/).

Salt Bootstrap maintainers will review your fix. If everything is OK and all
tests pass, you fix will be merged into Salt Bootstrap's code.

### Branches

There are two main branches in the Salt Bootstrap repository:

- develop
- stable

All fixes and features should be submitted to the `develop` branch. The `stable`
branch only contains released versions of the bootstrap script.

## Pull Requests

The Salt Bootstrap repo has several pull request checks that must pass before
a bug fix or feature implementation can be merged in.

### PR Tests

There are several Jenkins jobs that run on each Pull Request. Most of these are
CI jobs that set up different steps, such as setting up the job, cloning the
repo from the PR, etc.

#### Lint Check

The pull request test that matters the most, and the contributor is directly 
responsible for fixing, is the Lint check. This check *must* be passing before
the contribution can be merged into the codebase.

If the lint check has failed on your pull request, you can view the errors by
clicking `Details` in the test run output. Then, click the `Violations` link on
the left side. There you will see a list of files that have errors. By clicking
on the file, you will see `!` icons on the affected line. Hovering over the `!`
icons will explain what the issue is.

To run the lint tests locally before submitting a pull request, use the
`tests/runtests.py` file. The `-L` option runs the lint check:

```
python tests/runtests.py -L
```

### GPG Verification

SaltStack has enabled [GPG Probot](https://probot.github.io/apps/gpg/) to
enforce GPG signatures for all commits included in a Pull Request.

In order for the GPG verification status check to pass, *every* contributor in
the pull request must:

- Set up a GPG key on local machine
- Sign all commits in the pull request with key
- Link key with GitHub account

This applies to all commits in the pull request.

GitHub hosts a number of
[help articles](https://help.github.com/articles/signing-commits-with-gpg/) for
creating a GPG key, using the GPG key with `git` locally, and linking the GPG
key to your GitHub account. Once these steps are completed, the commit signing
verification will look like the example in GitHub's
[GPG Signature Verification feature announcement](https://github.com/blog/2144-gpg-signature-verification).

## Release Cadence

There is no defined release schedule for the bootstrap script at this time.
Typically, SaltStack's release team determines when it would be good to release
a new stable version.

Timing the release usually involves an analysis of the following:
 
- Updates for major feature releases in [Salt](https://github.com/saltstack/salt)
- Support for new versions of major operating systems
- Types of fixes submitted to `develop` since the last release
- Fixes needed for inclusion in an upcoming version of [Salt](https://github.com/saltstack/salt)
- Length of time since the last bootstrap release

## Adding Support for Other Operating Systems

The following operating systems are detected, but Salt and its dependency
installation functions are not developed yet:

- BSD:
    - NetBSD
- Linux:
    - Slackware
- SunOS:
    - OpenIndiana
    - Oracle Solaris
    - OmniOS (Illumos)


In order to install Salt for a distribution, you need to define the following:

1. To Install Dependencies, which is required, one of:

    ```
    install_<distro>_<major_version>_<install_type>_deps
    install_<distro>_<major_version>_<minor_version>_<install_type>_deps
    install_<distro>_<major_version>_deps
    install_<distro>_<major_version>_<minor_version>_deps
    install_<distro>_<install_type>_deps
    install_<distro>_deps
    ```

2. Optionally, define a minion configuration function, which will be called if the
   ``-c`` option is passed. One of:

    ```
    config_<distro>_<major_version>_<install_type>_salt
    config_<distro>_<major_version>_<minor_version>_<install_type>_salt
    config_<distro>_<major_version>_salt
    config_<distro>_<major_version>_<minor_version>_salt
    config_<distro>_<install_type>_salt
    config_<distro>_salt
    config_salt (THIS ONE IS ALREADY DEFINED AS THE DEFAULT)
    ```

3. Optionally, define a Salt master pre-seed function, which will be called if the
   ``-k`` (pre-seed master keys) option is passed. One of:

    ```
    preseed_<distro>_<major_version>_<install_type>_master
    preseed_<distro>_<major_version>_<minor_version>_<install_type>_master
    preseed_<distro>_<major_version>_master
    preseed_<distro>_<major_version>_<minor_version>_master
    preseed_<distro>_<install_type>_master
    preseed_<distro>_master
    preseed_master (THIS ONE IS ALREADY DEFINED AS THE DEFAULT)
    ```

4. To install salt, which, of course, is required, one of:

    ```
    install_<distro>_<major_version>_<install_type>
    install_<distro>_<major_version>_<minor_version>_<install_type>
    install_<distro>_<install_type>
    ```

5. Optionally, define a post install function, one of:

    ```
    install_<distro>_<major_version>_<install_type>_post
    install_<distro>_<major_version>_<minor_version>_<install_type>_post
    install_<distro>_<major_version>_post
    install_<distro>_<major_version>_<minor_version>_post
    install_<distro>_<install_type>_post
    install_<distro>_post
    ```

6. Optionally, define a start daemons function, one of:

    ```
    install_<distro>_<major_version>_<install_type>_restart_daemons
    install_<distro>_<major_version>_<minor_version>_<install_type>_restart_daemons
    install_<distro>_<major_version>_restart_daemons
    install_<distro>_<major_version>_<minor_version>_restart_daemons
    install_<distro>_<install_type>_restart_daemons
    install_<distro>_restart_daemons
    ```

**NOTE**

The start daemons function should be able to restart any daemons which are running, or
start if they're not running.

7. Optionally, define a daemons running function, one of:

    ```
    daemons_running_<distro>_<major_version>_<install_type>
    daemons_running_<distro>_<major_version>_<minor_version>_<install_type>
    daemons_running_<distro>_<major_version>
    daemons_running_<distro>_<major_version>_<minor_version>
    daemons_running_<distro>_<install_type>
    daemons_running_<distro>
    daemons_running  (THIS ONE IS ALREADY DEFINED AS THE DEFAULT)
    ```

8. Optionally, check enabled Services:

    ```
    install_<distro>_<major_version>_<install_type>_check_services
    install_<distro>_<major_version>_<minor_version>_<install_type>_check_services
    install_<distro>_<major_version>_check_services
    install_<distro>_<major_version>_<minor_version>_check_services
    install_<distro>_<install_type>_check_services
    install_<distro>_check_services
    ```

**NOTE**

The bootstrapping script must be plain POSIX `sh` only, **not** `bash` or another shell script.
By design, the targeting for each operating system and version is very specific. Assumptions of
supported versions or variants should not be made, to avoid failed or broken installations.

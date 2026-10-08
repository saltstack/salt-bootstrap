# shellcheck shell=sh

Describe '-e pip requirements file'
  Include "$(bootstrap_functions __validate_pip_requirements __install_pip_requirements __start_guard_needed __service_start_guard_on __service_start_guard_off)"

  BS_TRUE=1
  BS_FALSE=0

  # Mocks: capture messages instead of printing colours
  echoerror() { echo "error: $*" >&2; }
  echodebug() { :; }
  echoinfo() { echo "info: $*" >&2; }
  echowarn() { echo "warn: $*" >&2; }

  setup() {
    # The result must not depend on the umask of whoever runs the specs, files
    # that are group writable make the validation warn
    ORIG_UMASK=$(umask)
    umask 022
    WORK=$(mktemp -d)
    CALLS="$WORK/calls"
    : > "$CALLS"
    ITYPE="onedir"
    DISTRO_NAME_L="debian"
    _CONFIG_ONLY=$BS_FALSE
    _PIP_REQUIREMENTS_FILE="null"
    _START_GUARD_ACTIVE=$BS_FALSE
    printf '# Salt Extensions\nsaltext-foo==1.2.3\n' > "$WORK/requirements.txt"
    ORIG_PATH=$PATH
    ORIG_PWD=$(pwd)
  }
  cleanup() {
    umask "$ORIG_UMASK"
    PATH=$ORIG_PATH
    cd "$ORIG_PWD" || return 1
    rm -rf "$WORK"
  }
  BeforeEach setup
  AfterEach cleanup

  Describe '__validate_pip_requirements'
    It 'does nothing when -e was not passed'
      When call __validate_pip_requirements
      The status should be success
      The stderr should eq ''
    End

    It 'accepts a requirements file for a onedir install'
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be success
      The variable _PIP_REQUIREMENTS_FILE should eq "$WORK/requirements.txt"
    End

    It 'turns a relative path into an absolute one'
      cd "$WORK" || return 1
      _PIP_REQUIREMENTS_FILE="./requirements.txt"
      When call __validate_pip_requirements
      The status should be success
      The variable _PIP_REQUIREMENTS_FILE should eq "$WORK/requirements.txt"
    End

    It 'rejects installs that are not onedir'
      ITYPE="git"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'only supported for onedir installs'
    End

    It 'rejects macOS'
      DISTRO_NAME_L="macosx"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'not supported on macOS'
    End

    It 'rejects configuration only mode'
      _CONFIG_ONLY=$BS_TRUE
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'can not be used with -C'
    End

    It 'rejects a file that does not exist'
      _PIP_REQUIREMENTS_FILE="$WORK/missing.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'does not exist or is not readable'
    End

    It 'rejects a directory'
      _PIP_REQUIREMENTS_FILE="$WORK"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'does not exist or is not readable'
    End

    It 'rejects a file with only comments and blank lines'
      printf '# nothing here\n\n   \n  # still nothing\n' > "$WORK/empty.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/empty.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'does not list any packages'
    End

    It 'accepts a file with an index option and a package'
      printf -- '--index-url https://pypi.example.com/simple\nsaltext-foo\n' > "$WORK/index.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/index.txt"
      When call __validate_pip_requirements
      The status should be success
    End

    It 'rejects a file that is writable by everyone'
      chmod 666 "$WORK/requirements.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be failure
      The stderr should include 'writable by everyone'
    End

    It 'warns about a file that is writable by its group but accepts it'
      chmod 664 "$WORK/requirements.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __validate_pip_requirements
      The status should be success
      The stderr should include 'writable by its group'
    End

    It 'does not mistake a symlink for a writable file'
      chmod 644 "$WORK/requirements.txt"
      ln -s "$WORK/requirements.txt" "$WORK/link.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/link.txt"
      When call __validate_pip_requirements
      The status should be success
      The stderr should eq ''
    End
  End

  Describe '__install_pip_requirements'
    # A stand-in salt-pip that records how it was called
    fake_salt_pip() {
      mkdir -p "$WORK/bin"
      cat > "$WORK/bin/salt-pip" <<EOF
#!/bin/sh
echo "cwd=\$(pwd)" >> "$CALLS"
echo "args=\$*" >> "$CALLS"
exit \${FAKE_SALT_PIP_EXIT:-0}
EOF
      chmod +x "$WORK/bin/salt-pip"
      _SALT_PIP_PATHS="$WORK/bin/salt-pip"
    }

    It 'does nothing when -e was not passed'
      When call __install_pip_requirements
      The status should be success
    End

    It 'runs salt-pip install -r'
      fake_salt_pip
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __install_pip_requirements
      The status should be success
      The stderr should include 'Installing the Python packages'
      The contents of file "$CALLS" should include "args=install -r $WORK/requirements.txt"
    End

    # "python -m pip" puts the working directory first on sys.path, so running
    # it from the directory of the file would let anyone who can write there
    # run code as root
    It 'does not run salt-pip from the directory of the requirements file'
      fake_salt_pip
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __install_pip_requirements
      The status should be success
      The stderr should include 'Installing the Python packages'
      The contents of file "$CALLS" should include "cwd=/"
      The contents of file "$CALLS" should not include "cwd=$WORK"
    End

    It 'does not look for salt-pip in the PATH'
      fake_salt_pip
      _SALT_PIP_PATHS="$WORK/not-there/salt-pip"
      PATH="$WORK/bin:$PATH"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __install_pip_requirements
      The status should be failure
      The stderr should include 'salt-pip was not found'
    End

    It 'does not print the contents of the file'
      fake_salt_pip
      printf -- '--index-url https://user:s3cret@pypi.example.com/simple\nsaltext-foo\n' > "$WORK/private.txt"
      _PIP_REQUIREMENTS_FILE="$WORK/private.txt"
      When call __install_pip_requirements
      The status should be success
      The stderr should not include 's3cret'
    End

    It 'fails with a hint about -p when salt-pip fails'
      fake_salt_pip
      FAKE_SALT_PIP_EXIT=1
      export FAKE_SALT_PIP_EXIT
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __install_pip_requirements
      The status should be failure
      The stderr should include 'Failed to install the packages'
      The stderr should include '-p build-essential'
    End

    It 'fails when salt-pip can not be found'
      _SALT_PIP_PATHS="$WORK/not-there/salt-pip"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __install_pip_requirements
      The status should be failure
      The stderr should include 'salt-pip was not found'
    End
  End

  Describe '__start_guard_needed'
    It 'is needed on Debian when -e was passed'
      DISTRO_NAME_L="debian"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __start_guard_needed
      The status should be success
    End

    It 'is needed on Ubuntu when -e was passed'
      DISTRO_NAME_L="ubuntu"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __start_guard_needed
      The status should be success
    End

    It 'is not needed on RPM based distributions'
      DISTRO_NAME_L="rocky_linux"
      _PIP_REQUIREMENTS_FILE="$WORK/requirements.txt"
      When call __start_guard_needed
      The status should be failure
    End

    It 'is not needed without -e'
      DISTRO_NAME_L="debian"
      When call __start_guard_needed
      The status should be failure
    End
  End

  Describe 'service start guard'
    setup_guard() {
      _POLICY_RC_D="$WORK/policy-rc.d"
      unset _POLICY_RC_D_BACKUP
    }
    BeforeEach setup_guard

    It 'installs an executable policy-rc.d that denies starting services'
      When call __service_start_guard_on
      The status should be success
      The variable _START_GUARD_ACTIVE should eq 1
      The path "$WORK/policy-rc.d" should be executable
      The contents of file "$WORK/policy-rc.d" should include 'exit 101'
    End

    It 'removes the policy-rc.d again when there was none before'
      __service_start_guard_on
      When call __service_start_guard_off
      The status should be success
      The variable _START_GUARD_ACTIVE should eq 0
      The path "$WORK/policy-rc.d" should not be exist
      The path "$WORK/policy-rc.d.salt-bootstrap-backup" should not be exist
    End

    It 'puts an existing policy-rc.d back'
      printf '#!/bin/sh\necho original\n' > "$WORK/policy-rc.d"
      chmod 755 "$WORK/policy-rc.d"
      __service_start_guard_on
      When call __service_start_guard_off
      The status should be success
      The contents of file "$WORK/policy-rc.d" should include 'echo original'
      The path "$WORK/policy-rc.d" should be executable
      The path "$WORK/policy-rc.d.salt-bootstrap-backup" should not be exist
    End
  End
End

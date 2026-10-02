# shellcheck shell=sh

Describe '-R custom repository URL'
  Include "$(bootstrap_functions __rewrite_repo_url __install_saltstack_rhel_onedir_repository)"

  # Same layout as the salt.repo published in salt-install-guide
  SALT_REPO='[salt-repo-3006-lts]
name=Salt Repo for Salt v3006 LTS
baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/
enabled=1
gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public

[salt-repo-latest]
name=Salt Repo for Salt LATEST release
baseurl=https://packages.broadcom.com/artifactory/saltproject-rpm/
enabled=0
gpgkey=https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public'

  setup() {
    WORK=$(mktemp -d)
    YUM_REPO_FILE="$WORK/salt.repo"
    CALLS="$WORK/calls"
    : > "$CALLS"
  }
  cleanup() { rm -rf "$WORK"; }
  BeforeEach setup
  AfterEach cleanup

  Describe '__rewrite_repo_url'
    It 'points every Broadcom URL at _REPO_URL'
      printf '%s\n' "$SALT_REPO" > "$YUM_REPO_FILE"
      _REPO_URL="repo.example.com/myrepo"
      When call __rewrite_repo_url "$YUM_REPO_FILE"
      The status should be success
      The contents of file "$YUM_REPO_FILE" should not include 'packages.broadcom.com'
      The contents of file "$YUM_REPO_FILE" should include 'baseurl=https://repo.example.com/myrepo/saltproject-rpm/'
      The contents of file "$YUM_REPO_FILE" should include 'gpgkey=https://repo.example.com/myrepo/api/security/keypair/SaltProjectKey/public'
    End

    It 'keeps sections and enabled flags unchanged'
      printf '%s\n' "$SALT_REPO" > "$YUM_REPO_FILE"
      _REPO_URL="repo.example.com/myrepo"
      __rewrite_repo_url "$YUM_REPO_FILE"
      When call grep -c '^enabled=' "$YUM_REPO_FILE"
      The output should eq 2
    End

    It 'handles & and # in the URL'
      printf '%s\n' "$SALT_REPO" > "$YUM_REPO_FILE"
      _REPO_URL='repo.example.com/my&repo#1'
      When call __rewrite_repo_url "$YUM_REPO_FILE"
      The contents of file "$YUM_REPO_FILE" should include 'baseurl=https://repo.example.com/my&repo#1/saltproject-rpm/'
    End

    It 'does nothing when the file does not exist'
      When call __rewrite_repo_url "$WORK/missing.repo"
      The status should be success
    End
  End

  Describe '__install_saltstack_rhel_onedir_repository'
    BS_TRUE=1
    BS_FALSE=0
    ONEDIR_REV="latest"
    _PY_EXE="python3"
    _PY_MAJOR_VERSION=3
    _REPO_URL="repo.example.com/myrepo"

    # Mocks: no network, no package manager
    __fetch_url() { printf '%s\n' "$SALT_REPO" > "$1"; echo "fetch $1" >> "$CALLS"; }
    yum() { echo "yum $*" >> "$CALLS"; }
    echowarn() { echo "warn: $*" >&2; }

    It 'downloads salt.repo and points it at the custom URL'
      _FORCE_OVERWRITE=$BS_FALSE
      When call __install_saltstack_rhel_onedir_repository
      The status should be success
      The contents of file "$YUM_REPO_FILE" should not include 'packages.broadcom.com'
      The contents of file "$YUM_REPO_FILE" should include 'repo.example.com/myrepo/saltproject-rpm/'
      The contents of file "$CALLS" should include 'yum config-manager --set-enabled salt-repo-latest'
    End

    It 'leaves an existing salt.repo alone without -F'
      printf 'existing\n' > "$YUM_REPO_FILE"
      _FORCE_OVERWRITE=$BS_FALSE
      ONEDIR_REV="3007"
      When call __install_saltstack_rhel_onedir_repository
      The status should be success
      The stderr should include 'salt.repo already exists'
      The contents of file "$YUM_REPO_FILE" should eq 'existing'
      The contents of file "$CALLS" should not include 'fetch'
    End

    It 'replaces an existing salt.repo with -F and still honors -R'
      printf 'existing\n' > "$YUM_REPO_FILE"
      _FORCE_OVERWRITE=$BS_TRUE
      When call __install_saltstack_rhel_onedir_repository
      The status should be success
      The contents of file "$YUM_REPO_FILE" should not include 'packages.broadcom.com'
      The contents of file "$YUM_REPO_FILE" should include 'repo.example.com/myrepo/saltproject-rpm/'
    End
  End
End

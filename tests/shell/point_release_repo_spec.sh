# shellcheck shell=sh

# Regression test for #2147: for a point release the RPM repository functions
# write their own salt.repo section, and its baseurl serves every major. Without
# an exclude= line the first yum/dnf update moves to the newest Salt.
Describe 'point release salt.repo'
  Include "$(bootstrap_functions __salt_version_string __salt_repo_exclude_majors __rewrite_repo_url __install_saltstack_rhel_onedir_repository __install_saltstack_fedora_onedir_repository)"

  BS_TRUE=1
  BS_FALSE=0
  _FORCE_OVERWRITE=$BS_FALSE
  _PY_EXE="python3"
  _PY_MAJOR_VERSION=3
  _REPO_URL="packages.broadcom.com/artifactory"

  # Mocks: no network, no package manager
  __fetch_url() { printf '[salt-repo-latest]\n' > "$1"; }
  yum() { :; }
  dnf() { :; }
  echodebug() { :; }

  setup() {
    WORK=$(mktemp -d)
    YUM_REPO_FILE="$WORK/salt.repo"
  }
  cleanup() { rm -rf "$WORK"; }
  BeforeEach setup
  AfterEach cleanup

  Parameters
    __install_saltstack_rhel_onedir_repository              "3006.26"   "*3007* *3008* *3009* *3010*"
    __install_saltstack_fedora_onedir_repository            "3007.15"   "*3006* *3008* *3009* *3010*"
    __install_saltstack_rhel_onedir_repository              "3008.1-1"  "*3006* *3007* *3009* *3010*"
  End

  It "$1 keeps $2 on its major"
    ONEDIR_REV="$2"
    When call "$1"
    The status should be success
    The contents of file "$YUM_REPO_FILE" should include "[salt-repo-$2-lts]"
    The contents of file "$YUM_REPO_FILE" should include "exclude=$3"
  End
End

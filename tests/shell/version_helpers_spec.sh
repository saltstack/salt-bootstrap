# shellcheck shell=sh

Describe 'version and string helpers'
  Include "$(bootstrap_functions __parse_version_string __unquote_string __camelcase_split __derive_debian_numeric_version)"

  Describe '__parse_version_string'
    Parameters
      "20.04"       "20.04"
      "8.4.2105"    "8.4"
      "Rocky 9"     "9"
      "7"           "7"
      "rolling"     ""
    End

    It "parses '$1' as '$2'"
      When call __parse_version_string "$1"
      The output should eq "$2"
    End
  End

  Describe '__unquote_string'
    Parameters
      '"ubuntu"'  "ubuntu"
      "'debian'"  "debian"
      "fedora"    "fedora"
    End

    It "unquotes $1"
      When call __unquote_string "$1"
      The output should eq "$2"
    End
  End

  Describe '__camelcase_split'
    It 'splits CamelCased names'
      When call __camelcase_split "RedHatEnterpriseServer"
      The output should eq "Red Hat Enterprise Server"
    End
  End

  Describe '__derive_debian_numeric_version'
    echowarn() { echo "warn: $*" >&2; }

    It 'keeps a numeric version as is'
      When call __derive_debian_numeric_version "12.5"
      The output should eq "12.5"
    End

    It 'maps a testing codename to its release'
      When call __derive_debian_numeric_version "bookworm/sid"
      The output should eq "12.0"
    End

    It 'warns about an unknown codename'
      When call __derive_debian_numeric_version "mystery/sid"
      The stderr should include "Unable to parse the Debian Version"
      The output should eq ""
    End
  End
End

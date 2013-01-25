#!/bin/bash - 
#===============================================================================
#
#          FILE: .travis-ci-test.sh
#
#         USAGE: ./.travis-ci-test.sh
#
#   DESCRIPTION: Run several tests against the bootstrap script
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: https://github.com/saltstack/salt-bootstrap
#        AUTHOR: Pedro Algarvio (s0undt3ch), pedro@algarvio.me
#  ORGANIZATION: Salt Stack (saltstack.org)
#       CREATED: 32/01/2013 06:01:27 PM WET
#===============================================================================

set -o nounset                              # Treat unset variables as an error


if [ $(whoami) != "root" ] ; then
    title="You need to run this script as root."
    line="$(printf "%${COLUMNS}s" "")"
    printf "\033[1;31m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
    printf "\033[1;31m%s\033[0m\n" "${line// /*}"
    exit 1
fi


# Change to the scripts parent directory
cd $(dirname $0)

# Find out the available columns on our tty
COLUMNS=$(tput cols || 80)


title_echo() {
    title="$1"
    line="$(printf "%${COLUMNS}s" "")"
    printf "\033[0;33m%s\033[0m\n" "${line// /*}"
    printf "\033[0;33m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
}

failed_echo() {
    title="FAILED"
    line="$(printf "%${COLUMNS}s" "")"
    printf "\033[1;31m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
    printf "\033[1;31m%s\033[0m\n" "${line// /*}"
    exit 1
}

passed_echo() {
    title="OK"
    line="$(printf "%${COLUMNS}s" "")"
    printf "\033[1;32m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
    printf "\033[1;32m%s\033[0m\n" "${line// /*}"
}

cleanup() {
    apt-get remove -y -o DPkg::Options::=--force-confold --purge salt-master salt-minion salt-syndic
    apt-get autoremove -y -o DPkg::Options::=--force-confold --purge
    [ -d /tmp/git ] && rm -rf /tmp/git
    return 0
}

title_echo "Running checkbashisms"
/usr/bin/checkbashisms -pxfn bootstrap-salt-minion.sh && passed_echo || failed_echo

title_echo "Passing '-N'(no minion) without passing '-M'(install master) or '-S'(install syndic) fails"
./bootstrap-salt-minion.sh -N && failed_echo || passed_echo

title_echo "Using an unknown installation type fails"
./bootstrap-salt-minion.sh foobar && failed_echo || passed_echo

title_echo "Installing using bash"
(/bin/bash bootstrap-salt-minion.sh && salt-minion --versions-report && cleanup) && passed_echo || failed_echo

title_echo "Installing using sh"
(./bootstrap-salt-minion.sh && salt-minion --versions-report && cleanup) && passed_echo || failed_echo

title_echo "Installing stable with sh"
(./bootstrap-salt-minion.sh stable && salt-minion --versions-report && cleanup) && passed_echo || failed_echo

title_echo "Installing ubuntu daily packages using sh"
(./bootstrap-salt-minion.sh daily && salt-minion --versions-report && cleanup) && passed_echo || failed_echo

title_echo "Installing stable piped through sh"
(cat ./bootstrap-salt-minion.sh | sh && salt-minion --versions-report && cleanup) && passed_echo || failed_echo

title_echo "Installing latest develop branch from git"
(./bootstrap-salt-minion.sh git develop && salt --versions-report && cleanup ) && passed_echo || failed_echo

title_echo "Installing from a specific git tag"
(./bootstrap-salt-minion.sh git v0.12.1 && salt --versions-report && cleanup ) && passed_echo || failed_echo

title_echo "Installing from a specific git sha commit"
(./bootstrap-salt-minion.sh git bf1d7dfb733a6133d6a750e0ab63a27e72cf7e81 && salt --versions-report && cleanup ) && passed_echo || failed_echo

exit 0

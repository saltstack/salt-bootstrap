#!/bin/bash - 
#===============================================================================
#
#          FILE: .travis-ci-test.sh
#
#         USAGE: ./.travis-ci-test.sh
#
#   DESCRIPTION: 
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Pedro Algarvio (s0undt3ch), pedro@algarvio.me
#  ORGANIZATION: UfSoft.org
#       CREATED: 01/23/2013 06:01:27 PM WET
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

COLUMNS=$(tput cols) || 80

title_echo() {
	title="$1"
	line="$(printf "%${COLUMNS}s" "")"
	printf "\033[0;33m%s\033[0m\n" "${line// /*}"
	printf "\033[0;33m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
#	printf "\033[1;34m%s\033[0m\n" "${line// /*}"
}

failed_echo() {
	title="FAILED"
	line="$(printf "%${COLUMNS}s" "")"
#	printf "\031[1;34m%s\033[0m\n" "${line// /*}"
	printf "\031[1;34m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
	printf "\031[1;34m%s\033[0m\n" "${line// /*}"
	exit 1
}

passed_echo() {
	title="OK"
	line="$(printf "%${COLUMNS}s" "")"
#	printf "\033[1;32m%s\033[0m\n" "${line// /*}"
	printf "\033[1;32m%*s\033[0m\n" $(((${#title}+$COLUMNS)/2)) "$title"
	printf "\033[1;32m%s\033[0m\n" "${line// /*}"
}

title_echo "Running checkbashisms"
/usr/bin/checkbashisms -pxfn bootstrap-salt-minion.sh && passed_echo || failed_echo

title_echo "Installing using bash"
(sudo /bin/bash bootstrap-salt-minion.sh && salt-minion --versions-report && sudo apt-get remove salt-common salt-minion) && passed_echo || failed_echo

title_echo "Installing using sh"
(sudo ./bootstrap-salt-minion.sh && salt-minion --versions-report && sudo apt-get remove salt-common salt-minion) && passed_echo || failed_echo

title_echo "Installing stable with sh"
(sudo ./bootstrap-salt-minion.sh stable && salt-minion --versions-report && sudo apt-get remove salt-common salt-minion) && passed_echo || failed_echo

title_echo "Installing ubuntu daily packages using sh"
(sudo ./bootstrap-salt-minion.sh daily && salt-minion --versions-report && sudo apt-get remove salt-common salt-minion) && passed_echo || failed_echo

title_echo "Using an unknown installation type fails"
sudo ./bootstrap-salt-minion.sh foobar && failed_echo || passed_echo

title_echo "Installing stable piped through sh"
(cat ./bootstrap-salt-minion.sh | sudo sh && salt-minion --versions-report && sudo apt-get remove salt-common salt-minion) && passed_echo || failed_echo

title_echo "Installing latest develop branch from git"
(sudo ./bootstrap-salt-minion.sh git develop && salt --versions-report && sudo rm -rf /tmp/git ) && passed_echo || failed_echo

title_echo "Installing from a specific git tag"
(sudo ./bootstrap-salt-minion.sh git v0.12.1 && salt --versions-report && sudo rm -rf /tmp/git ) && passed_echo || failed_echo

title_echo "Installing from a specific git sha commit"
(sudo ./bootstrap-salt-minion.sh git bf1d7dfb733a6133d6a750e0ab63a27e72cf7e81 && salt --versions-report && sudo rm -rf /tmp/git ) && passed_echo || failed_echo


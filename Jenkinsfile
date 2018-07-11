import java.util.Random

Random rand = new Random()

// ONLY CHANGE THIS BIT PLEASE
def baseDistros = ["debian8",
                   "suse",
                   "centos6",
                   "arch",
                   "ubuntu-14.04",
                   "ubuntu-18.04",
                   "windows",
                   ]
def versions = ["stable", "git", "stable-old"]

def basePrDistros = ["ubuntu-16.04",
                     "centos7"]

def prVersions = ["stable", "git"]

// You probably shouldn't be messing with this stuff down here

def distros = (baseDistros + basePrDistros).unique()

def notifySuccessful(String stageName) {
    slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})" + "\n  Stage -- " + stageName)
}

def notifyFailed(String stageName) {
    slackSend (color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})" + "\n  Stage -- " + stageName)
}

def runKitchen(String distro) {
    echo "kitchen create ${distro}"
    echo "kitchen converge ${distro}"
    echo "kitchen destroy ${distro}"
}

def distroversions = []
for (d in distros) {
    for (v in versions) {
        distroversions = distroversions + ["${d}-${v}"]
    }
}

def prDistros = (basePrDistros + distros[rand.nextInt(baseDistros.size())]).unique()

def prDistroversions = []
for (d in prDistros) {
    for (v in prVersions) {
        prDistroversions = prDistroversions + ["${d}-${v}"]
    }
}

def makeSetupRuns(dv) {
    return {
        node {
            runKitchen("${dv}")
        }
    }
}

def setupRuns = distroversions.collectEntries {
    ["kitchen-${it}" : makeSetupRuns("${it}")]
}

def prSetupRuns = prDistroversions.collectEntries {
    ["kitchen-${it}" : makeSetupRuns("${it}")]
}

node ('bootstrap') {
    stage('checkout') { checkout scm }
    stage('shellcheck') {
        sh 'stack exec -- shellcheck -s sh -f checkstyle bootstrap-salt.sh | tee checkstyle.xml'
        checkstyle pattern: '**/checkstyle.xml'
        archiveArtifacts artifacts: '**/checkstyle.xml'
    }
    // if (env.CHANGE_ID) {
    //     // Running for a PR only runs against 4 random distros from a shorter list
    //     stage('kitchen-pr') {
    //         parallel prSetupRuns
    //     }
    // } else {
    //     // If we're not running for a pr we run *everything*
    //     stage('kitchen-all') {
    //         parallel setupRuns
    //     }
    // }
}

/*
 * TODO:
 * 1. Tests for each supported distro in bootstrap + branch shellcheck test (Shellcheck should be done)
 * 2. Each distro needs a "stable" install (installs stable packages from our repo) and a "git" install (installs off of a git tag)
 * 3. Running against each branch (stable, develop)
 * 4. And probably a small subset against each pull request (similar to what we do in salt)
 *
 * Distros to check:
 *     Debian 8
 *     Suse 42.1
 *     CentOS 7
 *     CentOS 6
 *     Arch
 *     Ubuntu 16.04
 *     Ubuntu 14.04
 *     Windows
 *
 * Runs each against develop and stable
 *
 */

def notifySuccessful(String stageName) {
  slackSend (color: '#00FF00', message: "SUCCESSFUL: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})" + "\n  Stage -- " + stageName)
}

def notifyFailed(String stageName) {
  slackSend (color: '#FF0000', message: "FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})" + "\n  Stage -- " + stageName)
}

pipeline {
    agent { label: 'bootstrap' }

    stages {
        stage('shellcheck') {
            steps {
                sh 'shellcheck -s sh -f checkstyle bootstrap-salt.sh | tee checkstyle.xml'
                checkstyle pattern: '**/checkstyle.xml'
                archiveArtifacts artifacts: '**/checkstyle.xml'
            }
        }
    }
}

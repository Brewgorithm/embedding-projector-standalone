properties([
  [$class: 'BuildDiscarderProperty', strategy: [$class: 'LogRotator', numToKeepStr: '2']],
  disableConcurrentBuilds()
])

node("build") {
  pull()

  try {
    notifyBuild('STARTED')
    runCI()
  } catch (e) {
    // If there was an exception thrown, the build failed
    currentBuild.result = "FAILED"
    throw e
  } finally {
    // Success or failure, always send notifications
    notifyBuild(currentBuild.result)
    sh "docker system prune -f"
  }
}

node("prod") {
  try {
    notifyBuild('DEPLOY STARTED')
    runDeploy()
  } catch (e) {
    // If there was an exception thrown, the build failed
    currentBuild.result = "FAILED"
    throw e
  } finally {
    // Success or failure, always send notifications
    notifyBuild(currentBuild.result)
    sh "docker system prune -f --volume"
  }
}

def runCI() {
  withEnv([
    "GIT_BRANCH=${env.BRANCH_NAME}",
    "JENKINS_URL=${env.JENKINS_URL}",
    "IMAGE_NAME=projector",
    "STACK_NAME=projector"
  ]) {
    prepare()
    build()
  }
}

def runDeploy() {
  withEnv([
    "GIT_BRANCH=${env.BRANCH_NAME}",
    "JENKINS_URL=${env.JENKINS_URL}",
    "IMAGE_NAME=projector",
    "STACK_NAME=projector"
  ]) {
    withCredentials([usernamePassword(
      credentialsId: "docker",
      usernameVariable: "USER",
      passwordVariable: "PASS"
    )]) {
      sh "docker login -u $USER -p $PASS"
    }
    tryPublish()
    release()
    sh "docker logout"
  }
}

def pull() {
  stage("Pull") {
    checkout scm
  }
}

def prepare() {
  stage("Prepare") {
    fileExists 'Dockerfile'
    sh "cat Dockerfile"
    sh "cat Jenkinsfile"
    sh "pwd"
    sh "ls -la"
  }
}

def build() {
  stage("Build") {
    withEnv([]) {
      sh "docker build -t ${env.IMAGE_NAME} ."
    }
  }
}

def tryPublish() {
  if (env.BRANCH_NAME == 'master') {
    publish()
  }
}

def release() {
  if (env.BRANCH_NAME == 'master') {
    production()
  }
}

def publish() {
  stage("Publish") {
    parallel(
      publishVersion: {
        if (env.BRANCH_NAME == 'master') {
          sh "docker tag ${env.IMAGE_NAME} \
            ${env.registry}/${env.IMAGE_NAME}:0.${env.BUILD_NUMBER}"
          sh "docker push \
            ${env.registry}/${env.IMAGE_NAME}:0.${env.BUILD_NUMBER}"
        }
      },
      publishLatest: {
        if (env.BRANCH_NAME == 'master') {
          sh "docker tag ${env.IMAGE_NAME} \
            ${env.registry}/${env.IMAGE_NAME}:latest"
          sh "docker push \
            ${env.registry}/${env.IMAGE_NAME}:latest"
        }
      }
    )
  }
}

def production() {
  stage("Production") {

    withEnv([
        "SERVICE_DOMAIN=projector.suggestbeer.com"
    ]) {
      try {
        withEnv([
          "TAG=0.${env.BUILD_NUMBER}"
        ]) {
          sh "docker stack deploy -c stack.yml --with-registry-auth ${env.STACK_NAME}"
        }
      } catch(e) {
        // Rollback to last
        withEnv([
          "TAG=last-prod"
        ]) {
          sh "docker stack deploy -c stack.yml --with-registry-auth ${env.STACK_NAME}"
          error "Deployment to Production has failed"
        }
      }
    }
  }

  stage("Publish Last Successful Production Deploy") {
    // QA deploy went successfully, tag last-prod as a rollback point
    sh "docker tag ${env.IMAGE_NAME} \
      ${env.registry}/${env.IMAGE_NAME}:last-prod"
    sh "docker push \
      ${env.registry}/${env.IMAGE_NAME}:last-prod"
  }
}

def notifyBuild(String buildStatus = 'STARTED') {
  // build status of null means successful
  buildStatus =  buildStatus ?: 'SUCCESSFUL'

  // Default values
  def colorName = 'RED'
  def colorCode = '#FF0000'
  def subject = "${buildStatus}: Job `${env.JOB_NAME}` Branch `${env.BRANCH_NAME}` Build `#${env.BUILD_NUMBER}`"
  def summary = "${subject} (${env.BUILD_URL})"
  def details = """<p>STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]':</p>
    <p>Check console output at &QUOT;<a href='${env.BUILD_URL}'>${env.JOB_NAME} [${env.BUILD_NUMBER}]</a>&QUOT;</p>"""

  // Override default values based on build status
  if (buildStatus == 'STARTED') {
    color = 'YELLOW'
    colorCode = '#FFFF00'
  } else if (buildStatus == 'SUCCESSFUL') {
    color = 'GREEN'
    colorCode = '#00FF00'
  } else {
    color = 'RED'
    colorCode = '#FF0000'
  }

  // Send notifications
  slackSend (color: colorCode, message: summary)
}
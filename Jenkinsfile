
pipeline {
  agent any

  options {
    ansiColor('xterm')
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    string(name: 'DOCKER_REGISTRY', defaultValue: 'docker.io', description: 'Docker registry (e.g. docker.io)')
    string(name: 'IMAGE_NAMESPACE', defaultValue: 'youruser', description: 'Docker namespace / username')
    booleanParam(name: 'DEPLOY', defaultValue: false, description: 'If true, run the deploy stage')
    string(name: 'GCP_PROJECT', defaultValue: '', description: '(Optional) GCP project for deploy-helm.sh')
    string(name: 'GKE_CLUSTER', defaultValue: '', description: '(Optional) GKE cluster for deploy-helm.sh')
    string(name: 'GKE_REGION', defaultValue: '', description: '(Optional) GKE region for deploy-helm.sh')
  }

  environment {
    IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT ?: 'local'}"
    CLIENT_IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAMESPACE}/gen-client:${env.IMAGE_TAG}"
    SERVER_IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAMESPACE}/gen-serv:${env.IMAGE_TAG}"
  }

  stages {
    stage('Prepare') {
      steps {
        echo "Preparing build..."

        checkout scm

        script {
          env.IMAGE_TAG = "${env.BUILD_NUMBER}"

          env.CLIENT_IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAMESPACE}/gen-client:${env.IMAGE_TAG}"

          env.SERVER_IMAGE = "${params.DOCKER_REGISTRY}/${params.IMAGE_NAMESPACE}/gen-serv:${env.IMAGE_TAG}"

          echo "Client image: ${env.CLIENT_IMAGE}"
          echo "Server image: ${env.SERVER_IMAGE}"
        }
      }
    }

    stage('Install Dependencies') {
      parallel {
        stage('Client: Install') {
          steps {
            dir('client') {
              bat 'npm ci'
            }
          }
        }
        stage('Server: Install') {
          steps {
            dir('server') {
              bat 'npm ci'
            }
          }
        }
      }
    }

    stage('Build') {
      parallel {
        stage('Client: Build') {
          steps {
            dir('client') {
              bat 'npm run build'
            }
          }
        }
        stage('Server: Build') {
          steps {
            dir('server') {
              bat 'if exist package.json (npm run build) else (echo no build)'
            }
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        script {
          bat 'docker --version || echo docker not found'
          bat "docker build -f client/next.dockerfile -t ${env.CLIENT_IMAGE} .\\client"
          bat "docker build -f server/node.dockerfile -t ${env.SERVER_IMAGE} .\\server"
        }
      }
    }

    stage('Docker Push') {
      when {
        expression { return params.DOCKER_REGISTRY?.trim() }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          bat 'echo Logging into registry %DOCKER_REGISTRY%'
          bat 'echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin %DOCKER_REGISTRY%'
          bat "docker push ${env.CLIENT_IMAGE}"
          bat "docker push ${env.SERVER_IMAGE}"
          bat 'docker logout %DOCKER_REGISTRY% || echo logout-failed'
        }
      }
    }

    stage('Deploy') {
      when {
        expression { return params.DEPLOY }
      }
      steps {
        echo 'Starting deploy...'
        script {
          if (fileExists('scripts/deploy-helm.sh')) {
            def bashAvailable = bat(script: 'bash --version >nul 2>nul', returnStatus: true) == 0
            if (!bashAvailable) {
              error 'Bash is not available on this Windows agent. Install Git Bash or run deploy from a Linux agent.'
            }
            withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
              bat 'if not exist "%USERPROFILE%\\.kube" mkdir "%USERPROFILE%\\.kube"'
              bat 'copy /Y "%KUBECONFIG_FILE%" "%USERPROFILE%\\.kube\\config"'
              bat "bash scripts/deploy-helm.sh ${params.GCP_PROJECT} ${params.GKE_CLUSTER} ${params.GKE_REGION}"
            }
          } else {
            error 'deploy-helm.sh not found in scripts/. Cannot deploy.'
          }
        }
      }
    }
  }

  post {
    always {
      echo 'Cleaning workspace and temporary files'
      bat 'docker logout %DOCKER_REGISTRY% || echo logout-failed'
      cleanWs()
    }
    success {
      echo 'Pipeline succeeded.'
    }
    failure {
      echo 'Pipeline failed.'
    }
  }
}

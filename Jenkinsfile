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
        echo "Building images with tag: ${env.IMAGE_TAG}"
        checkout scm
        script {
          def short = sh(script: 'git rev-parse --short HEAD || echo local', returnStdout: true).trim()
          env.IMAGE_TAG = "${env.BUILD_NUMBER}-${short}"
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
              sh 'npm ci'
            }
          }
        }
        stage('Server: Install') {
          steps {
            dir('server') {
              sh 'npm ci'
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
              sh 'npm run build'
            }
          }
        }
        stage('Server: Build') {
          steps {
            dir('server') {
              sh 'if [ -f package.json ]; then npm run build || true; fi'
            }
          }
        }
      }
    }

    stage('Docker Build') {
      steps {
        script {
          sh "docker --version || true"
          sh "docker build -f client/next.dockerfile -t ${env.CLIENT_IMAGE} ./client"
          sh "docker build -f server/node.dockerfile -t ${env.SERVER_IMAGE} ./server"
        }
      }
    }

    stage('Docker Push') {
      when {
        expression { return params.DOCKER_REGISTRY?.trim() }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
          sh 'echo "Logging into registry ${params.DOCKER_REGISTRY}"'
          sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin ${params.DOCKER_REGISTRY}'
          sh "docker push ${env.CLIENT_IMAGE}"
          sh "docker push ${env.SERVER_IMAGE}"
          sh 'docker logout ${params.DOCKER_REGISTRY} || true'
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
            withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG_FILE')]) {
              sh 'mkdir -p ~/.kube'
              sh 'cp $KUBECONFIG_FILE ~/.kube/config'
              sh 'chmod 600 ~/.kube/config'
              sh "chmod +x scripts/deploy-helm.sh && ./scripts/deploy-helm.sh ${params.GCP_PROJECT} ${params.GKE_CLUSTER} ${params.GKE_REGION}"
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
      sh 'docker logout ${params.DOCKER_REGISTRY} || true'
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

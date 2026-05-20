
pipeline {
  agent any

  options {
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  parameters {
    string(name: 'DOCKER_REGISTRY', defaultValue: 'docker.io', description: 'Docker registry (e.g. docker.io)')
    string(name: 'IMAGE_NAMESPACE', defaultValue: 'rajjaiswal23', description: 'Docker namespace / username')
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

    stage('Clean Workspace') {
      steps {
        cleanWs()
        checkout scm
      }
    }

    stage('Create Env Files') {
      steps {
        withCredentials([
          string(credentialsId: 'mongo-uri', variable: 'MONGO_URI'),
          string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
          string(credentialsId: 'jwt-user-secret', variable: 'JWT_USER_SECRET'),
          string(credentialsId: 'email-user', variable: 'EMAIL_USER'),
          string(credentialsId: 'email-pass', variable: 'EMAIL_PASS'),
          string(credentialsId: 'cloudinary-cloud-name', variable: 'CLOUDINARY_CLOUD_NAME'),
          string(credentialsId: 'cloudinary-api-key', variable: 'CLOUDINARY_API_KEY'),
          string(credentialsId: 'cloudinary-api-secret', variable: 'CLOUDINARY_API_SECRET')
        ]) {
          dir('server') {
            writeFile file: '.env', text: """
PORT=5555
NODE_ENV=development
CLIENT_URL=http://localhost:3005

MONGO_URI=${MONGO_URI}

JWT_SECRET=${JWT_SECRET}
JWT_USER_SECRET=${JWT_USER_SECRET}
JWT_EXPIRES_IN=1d

EMAIL_USER=${EMAIL_USER}
EMAIL_PASS=${EMAIL_PASS}

CLOUDINARY_CLOUD_NAME=${CLOUDINARY_CLOUD_NAME}
CLOUDINARY_API_KEY=${CLOUDINARY_API_KEY}
CLOUDINARY_API_SECRET=${CLOUDINARY_API_SECRET}
CLOUDINARY_FOLDER_NAME=genkart

RATE_LIMIT_WINDOW_MINUTES=15
RATE_LIMIT_MAX=100
"""
          }

          dir('client') {
            writeFile file: '.env', text: """
NEXT_PUBLIC_API_URL=http://localhost:5555
"""
          }
        }
      }
    }

    stage('Install Dependencies') {
      steps {
        dir('client') {
          bat 'npm cache clean --force'
          bat 'npm config set fetch-retries 5'
          bat 'npm config set fetch-retry-mintimeout 20000'
          bat 'npm config set fetch-retry-maxtimeout 120000'
          bat 'npm install --legacy-peer-deps --no-audit --no-fund'
        }

        dir('server') {
          bat 'npm cache clean --force'
          bat 'npm config set fetch-retries 5'
          bat 'npm config set fetch-retry-mintimeout 20000'
          bat 'npm config set fetch-retry-maxtimeout 120000'
          bat 'npm install --legacy-peer-deps --no-audit --no-fund'
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
              bat 'echo Backend build skipped'
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

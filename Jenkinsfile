pipeline {
    agent any

    options {
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_NAMESPACE    = 'rajjaiswal23'
        CLIENT_IMAGE       = "rajjaiswal23/gen-client:${env.BUILD_NUMBER}"
        SERVER_IMAGE       = "rajjaiswal23/gen-serv:${env.BUILD_NUMBER}"
        CLIENT_IMAGE_LATEST = 'rajjaiswal23/gen-client:latest'
        SERVER_IMAGE_LATEST = 'rajjaiswal23/gen-serv:latest'
        KUBECONFIG         = 'C:\\Users\\hp\\.kube\\config'
    }

    stages {

        // ── 1. Checkout ────────────────────────────────────────────────────────
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                echo "Build #${env.BUILD_NUMBER} — branch: ${env.GIT_BRANCH}"
            }
        }

        // ── 2. Write .env files from Jenkins credentials ───────────────────────
        stage('Create Env Files') {
            steps {
                withCredentials([
                    string(credentialsId: 'MONGO_URI',               variable: 'MONGO_URI'),
                    string(credentialsId: 'JWT_SECRET',              variable: 'JWT_SECRET'),
                    string(credentialsId: 'JWT_USER_SECRET',         variable: 'JWT_USER_SECRET'),
                    string(credentialsId: 'EMAIL_USER',              variable: 'EMAIL_USER'),
                    string(credentialsId: 'EMAIL_PASS',              variable: 'EMAIL_PASS'),
                    string(credentialsId: 'CLOUDINARY_CLOUD_NAME',   variable: 'CLOUDINARY_CLOUD_NAME'),
                    string(credentialsId: 'CLOUDINARY_API_KEY',      variable: 'CLOUDINARY_API_KEY'),
                    string(credentialsId: 'CLOUDINARY_API_SECRET',   variable: 'CLOUDINARY_API_SECRET')
                ]) {
                    script {
                        // Write server .env
                        writeFile file: 'server/.env', text: [
                            "PORT=5560",
                            "NODE_ENV=production",
                            "CLIENT_URL=http://localhost:3005",
                            "MONGO_URI=${MONGO_URI}",
                            "JWT_SECRET=${JWT_SECRET}",
                            "JWT_USER_SECRET=${JWT_USER_SECRET}",
                            "JWT_EXPIRES_IN=1d",
                            "EMAIL_USER=${EMAIL_USER}",
                            "EMAIL_PASS=${EMAIL_PASS}",
                            "CLOUDINARY_CLOUD_NAME=${CLOUDINARY_CLOUD_NAME}",
                            "CLOUDINARY_API_KEY=${CLOUDINARY_API_KEY}",
                            "CLOUDINARY_API_SECRET=${CLOUDINARY_API_SECRET}",
                            "CLOUDINARY_FOLDER_NAME=genkart",
                            "RATE_LIMIT_WINDOW_MINUTES=15",
                            "RATE_LIMIT_MAX=100"
                        ].join("\n")

                        // Write client .env
                        writeFile file: 'client/.env', text: [
                            "NEXT_PUBLIC_API=http://localhost:5560/api"
                        ].join("\n")
                    }
                }
            }
        }

        // ── 3. Install dependencies ────────────────────────────────────────────
        stage('Install: Client') {
            steps {
                dir('client') {
                    bat 'npm install --legacy-peer-deps --no-audit --no-fund'
                }
            }
        }

        stage('Install: Server') {
            steps {
                dir('server') {
                    bat 'npm install --legacy-peer-deps --no-audit --no-fund'
                }
            }
        }

        // ── 4. Build Next.js client ────────────────────────────────────────────
        stage('Build: Client') {
            steps {
                dir('client') {
                    bat 'npm run build'
                }
            }
        }

        // ── 5. Docker build ────────────────────────────────────────────────────
        stage('Docker Build') {
            steps {
                // Build with build-number tag, then also tag as :latest
                bat "docker build -f client\\next.dockerfile -t %CLIENT_IMAGE% -t %CLIENT_IMAGE_LATEST% client"
                bat "docker build -f server\\node.dockerfile -t %SERVER_IMAGE% -t %SERVER_IMAGE_LATEST% server"
            }
        }

        // ── 6. Docker push ─────────────────────────────────────────────────────
        stage('Docker Push') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    bat 'echo %DOCKER_PASS%| docker login -u %DOCKER_USER% --password-stdin'
                    // Push versioned tag
                    bat 'docker push %CLIENT_IMAGE%'
                    bat 'docker push %SERVER_IMAGE%'
                    // Also push :latest so K8s manifests always pull newest image
                    bat 'docker push %CLIENT_IMAGE_LATEST%'
                    bat 'docker push %SERVER_IMAGE_LATEST%'
                    bat 'docker logout || echo logout-skipped'
                }
            }
        }

        // ── 7. Deploy to Kubernetes ────────────────────────────────────────────
        stage('Deploy') {
            steps {
                bat 'minikube image load %CLIENT_IMAGE_LATEST%'
                bat 'minikube image load %SERVER_IMAGE_LATEST%'
                bat 'set KUBECONFIG=C:\\Users\\hp\\.kube\\config && kubectl apply -f k8s\\'
                bat 'set KUBECONFIG=C:\\Users\\hp\\.kube\\config && kubectl rollout restart deployment genkart-client'
                bat 'set KUBECONFIG=C:\\Users\\hp\\.kube\\config && kubectl rollout restart deployment genkart-server'
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded — images: ${env.CLIENT_IMAGE} | ${env.SERVER_IMAGE}"
        }
        failure {
            echo 'Pipeline FAILED. Check logs above.'
        }
        cleanup {
            cleanWs()
        }
    }
}

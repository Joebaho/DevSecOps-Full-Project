#!/bin/bash
set -euxo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

retry() {
  local attempts=5
  local wait_seconds=5
  local count=1

  until "$@"; do
    if [ "${count}" -ge "${attempts}" ]; then
      echo "Command failed after ${attempts} attempts: $*"
      return 1
    fi

    count=$((count + 1))
    sleep "${wait_seconds}"
  done
}

apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl fontconfig gnupg lsb-release software-properties-common unzip wget openjdk-21-jre

# AWS CLI
if ! command -v aws >/dev/null 2>&1; then
  retry curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  rm -rf /tmp/aws
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
fi

# Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu || true

# Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /etc/apt/keyrings/jenkins-keyring.asc
chmod a+r /etc/apt/keyrings/jenkins-keyring.asc
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
apt-get update -y
apt-get install -y jenkins
systemctl enable jenkins
systemctl start jenkins

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
  retry curl -fsSL -o /tmp/kubectl "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
fi

# eksctl
if ! command -v eksctl >/dev/null 2>&1; then
  retry curl --silent --location --output /tmp/eksctl.tar.gz "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz"
  tar xzf /tmp/eksctl.tar.gz -C /tmp
  install -o root -g root -m 0755 /tmp/eksctl /usr/local/bin/eksctl
fi

# Argo CD CLI
if ! command -v argocd >/dev/null 2>&1; then
  retry curl -fsSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
  install -o root -g root -m 0755 /tmp/argocd /usr/local/bin/argocd
fi

# SonarQube
retry docker pull sonarqube:lts-community

if docker ps -a --format '{{.Names}}' | grep -qx sonarqube; then
  docker start sonarqube || true
else
  docker run -d --name sonarqube --restart unless-stopped -p 9000:9000 sonarqube:lts-community
fi

kubectl version --client
eksctl version
argocd version --client
aws --version
docker ps --filter "name=sonarqube"

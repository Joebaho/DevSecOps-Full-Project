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
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common unzip wget openjdk-17-jre

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

# Trivy
curl -fsSL https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor -o /usr/share/keyrings/trivy.gpg
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list > /dev/null
apt-get update -y
apt-get install -y trivy

java -version
docker --version
trivy --version
aws --version

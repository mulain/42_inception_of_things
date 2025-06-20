#!/bin/bash
set -e

echo "=== GitLab Lightweight Installation Script ==="

# --- Check for helm ---
if ! command -v helm &>/dev/null; then
  echo "🔧 Installing Helm..."
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
  echo "✅ Helm already installed."
fi

# --- Add GitLab Helm repo ---
echo "Checking GitLab Helm repo..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update
echo "✅ GitLab Helm repo is ready."

# --- Create namespace if missing ---
if ! kubectl get namespace gitlab &>/dev/null; then
  echo "📁 Creating 'gitlab' namespace..."
  kubectl create namespace gitlab
else
  echo "✅ 'gitlab' namespace already exists."
fi

# --- Install GitLab chart with inline config ---
echo "🚀 Installing GitLab with inline configuration..."
helm upgrade --install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 600s \
  --set global.hosts.domain=app.com \
  --set global.hosts.externalIP=localhost \
  --set certmanager-issuer.email=knism@student.42wolfsburg.de \
  --set certmanager.install=false \
  --set prometheus.install=false \
  --set gitlab-runner.install=false \
  --set global.ingress.configureCertmanager=false \
  --set global.rails.bootsnap.enabled=false \
  --set gitlab.webservice.minReplicas=1 \
  --set gitlab.webservice.maxReplicas=1 \
  --set gitlab.webservice.workerProcesses=0 \
  --set gitlab.webservice.resources.requests.memory=600M \
  --set global.kas.enabled=false \
  --set gitlab.kas.minReplicas=1 \
  --set gitlab.kas.maxReplicas=1 \
  --set gitlab.gitlab-exporter.enabled=false \
  --set gitlab.toolbox.enabled=false \
  --set gitlab.sidekiq.enabled=false \
  --set gitlab.sidekiq.minReplicas=1 \
  --set gitlab.sidekiq.maxReplicas=1 \
  --set gitlab.sidekiq.resources.requests.memory=300M \
  --set gitlab.sidekiq.resources.requests.cpu=60m \
  --set gitlab.gitlab-shell.minReplicas=1 \
  --set gitlab.gitlab-shell.maxReplicas=1 \
  --set registry.hpa.minReplicas=1 \
  --set registry.hpa.maxReplicas=1 \
  \
  --set nginx-ingress.enabled=false \
  --set registry.enabled=false \
  --set postgresql.resources.requests.memory=200Mi \
  --set redis.allowEmptyPassword=true \
  --set redis.password="" \
  --set redis.resources.requests.memory=100Mi \
  --set global.hosts.http='localhost:8081' \
  --set global.hosts.externalUrl='http://localhost:8081' 

# --- Port forward GitLab (background) ---
if ! pgrep -f "port-forward svc/gitlab-webservice-default" > /dev/null; then
  echo "📡 Starting port-forward on localhost:8081..."
  kubectl port-forward svc/gitlab-webservice-default -n gitlab 8081:8080 > /dev/null 2>&1 &

  sleep 3
else
  echo "✅ Port-forward already running."
fi

# --- Get GitLab root password ---
echo "🔐 Fetching GitLab root password..."
until kubectl get secret -n gitlab gitlab-gitlab-initial-root-password &>/dev/null; do
  echo "⏳ Waiting for secret to be created..."
  sleep 5
done

kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 --decode
echo -e "\n✅ GitLab root password retrieved."

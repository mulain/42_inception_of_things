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
echo "🚀 Installing GitLab with yaml configuration..."
helm upgrade --install gitlab gitlab/gitlab -n gitlab -f gitlab-values.yaml

# --- Port forward GitLab Nginx Ingress (background) ---
if ! pgrep -f "port-forward svc/gitlab-nginx-ingress-controller" > /dev/null; then
  echo "📡 Starting port-forward on localhost:8081..."
  kubectl port-forward svc/gitlab-nginx-ingress-controller -n gitlab --address 0.0.0.0 8081:80 > /dev/null 2>&1 &
  sleep 5
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
echo "You can access GitLab at: http://gitlab.localhost:8081"

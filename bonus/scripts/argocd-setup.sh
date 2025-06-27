#!/bin/bash
set -e

# Ensure part 3 is installed

echo "🔧 Running Part 3 installation script..."
../../p3/scripts/install.sh

# Port forwarding for gitlab-gitlab-shell on random port (2226)

echo "🚀 Starting port-forward for gitlab-gitlab-shell SSH on localhost:2226"
kubectl -n gitlab port-forward svc/gitlab-gitlab-shell 2226:22 > /dev/null 2>&1 &
sleep 5  # wait for port-forward to be ready
echo "✅ Port forward started, PID: $!"

REPO_SLUG="iot_bonus"
APP_REPO="ssh://git@gitlab-gitlab-shell.gitlab.svc.cluster.local:22/root/$REPO_SLUG.git"
REPO="ssh://git@gitlab.localhost:2226/root/$REPO_SLUG.git"

CLONE_DIR="/tmp/repo_clone"
CONFS_DIR="/tmp/confs-copy"
APP_NAMESPACE="dev"

# Check SSH connectivity

ssh -T -p 2226 git@gitlab.localhost -o StrictHostKeyChecking=no

# Move config files to an absolute path

echo "📂 Copying conf files to absolute path: $CONFS_DIR..."
mkdir -p "$CONFS_DIR"
cp -r -p ../confs/* "$CONFS_DIR"

# Clone the repo if not already cloned

if [ ! -d "$CLONE_DIR" ]; then
    echo "📦 Cloning repository..."
    git clone "$REPO" "$CLONE_DIR" || exit 1
else
    echo "📁 Repository already cloned - skipping clone."
fi

cd "$CLONE_DIR" || exit 1

# Copy files

echo "📂 Copying files from $CONFS_DIR to $CLONE_DIR/confs..."
mkdir -p "$CLONE_DIR/confs"
cp -r -p "$CONFS_DIR/"* "$CLONE_DIR/confs/"

# Git configuration

echo "🔧 Configuring Git..."
git remote set-url origin "$REPO"
git config --local user.name "root"
git config --local user.email "your_email@example.com"

# Add and commit changes

echo "📦 Adding and committing changes to the repository..."
git add confs
git commit -m "Add configuration files" || echo "ℹ️ Nothing to commit. Ruh Roh?!"
git push
echo "✅ Git push complete."

# Add Repo to ArgoCD

echo "🚀 Adding ArgoCD repo $APP_REPO"
argocd repo add "$APP_REPO" \
    --ssh-private-key-path /root/.ssh/id_rsa \
    --insecure-skip-server-verification

# Creating ArgoCD app

echo "🧩 Creating ArgoCD application wil-playground-bonus..."
argocd app create wil-playground-bonus \
  --repo "$APP_REPO" \
  --path confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace "$APP_NAMESPACE" \
  --sync-policy automated

# Ensure the namespace exists

echo "🔧 Ensuring '$APP_NAMESPACE' namespace exists..."
kubectl get namespace "$APP_NAMESPACE" &>/dev/null || kubectl create namespace "$APP_NAMESPACE"

# Create RoleBinding for ArgoCD app controller

echo "⏳ Creating RoleBinding for Argo CD Application Controller in namespace '$APP_NAMESPACE'..."
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-application-controller-$APP_NAMESPACE
  namespace: $APP_NAMESPACE
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-application-controller
subjects:
- kind: ServiceAccount
  name: argocd-application-controller
  namespace: argocd
EOF
echo "✅ RoleBinding applied."

echo "✅ Argo CD setup and app deployment complete!"
echo "Use kubectl -n $APP_NAMESPACE get svc,pods -o wide to check the status."
echo "To access Argo CD UI, visit: http://localhost:8080"
echo "🔑 Retrieving Argo CD admin password..."
until ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null); do
  echo "Waiting for Argo CD admin secret to be available..."
  sleep 5
done
echo "✅ Retrieved Argo CD admin password."
echo "password: $ARGOCD_PASSWORD" 

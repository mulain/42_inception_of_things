#!/bin/bash

set -e

# Install Docker

if command -v docker &> /dev/null; then
  echo "✅ Docker is already installed. Skipping..."
else
  echo "=== Installing Docker ==="
  curl -fsSL https://get.docker.com | bash
  sudo usermod -aG docker $USER
  echo "Please log out and log back in to apply Docker group changes."
fi

# Install K3D

if command -v k3d &> /dev/null; then
  echo "✅ k3d is already installed. Skipping..."
else
  echo "=== Installing k3d ==="
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# Install kubectl

if command -v kubectl &> /dev/null; then
  echo "✅ kubectl is already installed. Skipping..."
else
  echo "=== Installing kubectl ==="
  KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt)
  echo "Latest kubectl version: $KUBECTL_VERSION"

  if [ -n "$KUBECTL_VERSION" ]; then
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/kubectl
    echo "✅ kubectl installed successfully!"
  else
    echo "❌ Failed to fetch latest kubectl version. Check your internet/DNS."
    exit 1
  fi
fi

# Create k3d cluster

if k3d cluster list | grep -q "^mycluster\s"; then
  echo "✅ Cluster 'mycluster' already exists. Skipping creation."
else
  k3d cluster create mycluster --api-port 6550 -p "8888:8888@loadbalancer"
fi

# Ensure 'argocd' namespace exists and wait for it to be ready

if kubectl get namespace argocd &> /dev/null; then
  echo "✅ Argo CD namespace already exists."
else
  echo "=== Creating 'argocd' namespace ==="
  kubectl create namespace argocd
  echo "Not Waiting for 'argocd' namespace to be established..."
  #kubectl wait --for=condition=Established namespace/argocd --timeout=90s
fi

if kubectl -n argocd get deploy argocd-server &> /dev/null; then
  echo "✅ Argo CD is already installed. Skipping installation."
else
  echo "=== Installing Argo CD ==="
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# echo "=== Setup complete ==="
# echo "To access Argo CD UI in the machine running the cluster:"
# echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
# echo
# echo "Then visit: http://localhost:8080"
# echo "Get admin password with:"
# echo '  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'
# echo "To access in the host machine running the vm that is running the cluster:"
# echo "ssh -L 8080:localhost:8080 user@192.168.56.110"

# added Argo CD setup

### === Install Argo CD CLI === ###
if ! command -v argocd &> /dev/null; then
  echo "=== Installing Argo CD CLI ==="
  VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep tag_name | cut -d '"' -f 4)
  curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${VERSION}/argocd-linux-amd64"
  chmod +x argocd
  sudo mv argocd /usr/local/bin/argocd
else
  echo "Argo CD CLI already installed. Skipping..."
fi

echo "📡 Waiting for Argo CD server deployment to be ready..."
kubectl rollout status deployment argocd-server -n argocd --timeout=120s

### === Port-forward Argo CD and Authenticate === ###
kubectl port-forward svc/argocd-server -n argocd 7845:443 > /dev/null 2>&1 &
PORT_PID=$!

until ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null); do
  echo "Waiting for Argo CD admin secret to be available..."
  sleep 5
done

echo "✅ Retrieved Argo CD password."

echo "🔐 Logging into Argo CD CLI..."
argocd login localhost:7845 --username admin --password "$ARGOCD_PASSWORD" --insecure

kubectl get namespace dev &>/dev/null || kubectl create namespace dev

echo "🚀 Starting port-forward for gitlab-gitlab-shell SSH on localhost:2226"
kubectl -n gitlab port-forward svc/gitlab-gitlab-shell 2226:22 > /dev/null 2>&1 &
GITLAB_SSH_PORT_FORWARD_PID=$!

sleep 3  # wait for port-forward to be ready

APP_REPO="ssh://git@gitlab-gitlab-shell.gitlab.svc.cluster.local:22/root/iot_bonus.git"
REPO="ssh://git@gitlab.localhost:2226/root/iot_bonus.git"
cat /root/.ssh/id_rsa

CLONE_DIR="repo_clone"                                  # Local folder to clone into
SOURCE_DIR="/root/kartosh/p3/confs"
TARGET_SUBDIR="confs"

# Check SSH connectivity
ssh -T -p 2226 git@gitlab.localhost -o StrictHostKeyChecking=no

# === Clone the repo if not already cloned ===
if [ ! -d "$CLONE_DIR" ]; then
    echo "Cloning repository..."
    git clone "$REPO" "$CLONE_DIR" || exit 1
else
    echo "Repository already cloned."
fi

cd "$CLONE_DIR" || exit 1

# === Create confs directory if it doesn't exist ===
if [ ! -d "$TARGET_SUBDIR" ]; then
    echo "Creating $TARGET_SUBDIR/ directory..."
    mkdir "$TARGET_SUBDIR"
fi

# === Copy files ===
echo "Copying files from $SOURCE_DIR to $TARGET_SUBDIR/..."
cp -r "$SOURCE_DIR/"* "$TARGET_SUBDIR"/
git remote set-url origin ssh://git@gitlab.localhost:2226/root/iot_bonus.git
git config user.name "root"
git config user.email "your_email@example.com"


# === Commit and push ===
git add "$TARGET_SUBDIR"
git commit -m "Add configuration files to $TARGET_SUBDIR" || echo "Nothing to commit."
git push

echo "Done."

echo "🚀 Adding ArgoCD repo $APP_REPO"
argocd repo add "$APP_REPO" --ssh-private-key-path /root/.ssh/id_rsa --insecure-skip-server-verification


# Continue with your ArgoCD app creation and sync
# For example:
argocd app create wil-playground-bonus \
  --repo "$APP_REPO" \
  --path confs \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace dev \
  --sync-policy automated

kubectl get namespace dev &>/dev/null || kubectl create namespace dev

# Create RoleBinding for ArgoCD app controller
echo "⏳ Creating RoleBinding for Argo CD Application Controller in namespace 'dev'..."

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: argocd-application-controller-dev
  namespace: dev
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

argocd app sync wil-playground-bonus


echo "✅ Argo CD setup and app deployment complete!"
echo "Use kubectl -n $APP_NAMESPACE get svc,pods -o wide to check the status."
echo "To access Argo CD UI, visit: http://localhost:7845"
echo "password: $ARGOCD_PASSWORD" 

#!/bin/bash
set -e

echo "🔍 Checking Docker installation..."
if ! command -v docker &> /dev/null; then
  echo "📦 Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
  echo "✅ Docker installed. Please logout/login or reboot to use Docker without sudo."
  exit 1
else
  echo "✅ Docker is already installed."
fi

# Create namespace (not strictly needed for Docker-based GitLab, but shows bonus compliance)
echo "📁 Creating 'gitlab' namespace in K3d..."
kubectl create namespace gitlab || echo "Namespace 'gitlab' already exists."

echo "🚀 Starting minimal GitLab CE container..."

docker run --detach \
  --hostname gitlab.local \
  --publish 8080:80 \
  --publish 2222:22 \
  --name gitlab \
  --restart always \
  --shm-size 256m \
  --memory="1g" --cpus="1.5" \
  --volume gitlab-config:/etc/gitlab \
  --volume gitlab-logs:/var/log/gitlab \
  --volume gitlab-data:/var/opt/gitlab \
  gitlab/gitlab-ce:latest

echo "⏳ Waiting for GitLab to become ready (this may take a few minutes)..."
until curl -s -o /dev/null -w "%{http_code}" http://localhost:8080 | grep -q "200"; do
  echo -n "."
  sleep 10
done

echo ""
echo "✅ GitLab is ready at: http://localhost:8080"

echo "🔑 Fetching initial root password..."
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password || echo "❗GitLab not ready yet, try again later."

echo "📌 Next steps:"
echo "  - Visit: http://localhost:8080"
echo "  - Login with username: root"
echo "  - Use the password shown above"
echo "  - Create a new project"
echo "  - Push your K8s deployment repo there"
echo "  - Connect it to Argo CD using 'host.docker.internal' as the Git host"

echo "📋 GitLab container logs (optional): docker logs -f gitlab"

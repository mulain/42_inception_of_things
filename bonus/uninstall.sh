#!/bin/bash
set -e

NAMESPACE="gitlab"
RELEASE="gitlab"

echo "Uninstalling GitLab Helm release..."
helm uninstall $RELEASE -n $NAMESPACE || echo "Helm release $RELEASE not found or already removed."

echo "Deleting namespace $NAMESPACE..."
kubectl delete namespace $NAMESPACE || echo "Namespace $NAMESPACE not found or already deleted."

echo "Waiting for namespace to terminate..."
while kubectl get namespace $NAMESPACE &> /dev/null; do
  echo "Namespace $NAMESPACE still terminating..."
  sleep 5
done

echo "✅ Uninstallation complete. You can now reinstall GitLab fresh."

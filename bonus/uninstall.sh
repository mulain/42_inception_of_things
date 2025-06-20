helm uninstall gitlab -n gitlab
kubectl delete namespace gitlab
echo "🗑️ GitLab uninstalled and namespace deleted."
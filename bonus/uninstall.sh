#helm uninstall gitlab -n gitlab
#kubectl delete namespace gitlab
rm -f /root/.ssh/id_rsa /root/.ssh/id_rsa.pub
ssh-keygen -f '/root/.ssh/known_hosts' -R '[gitlab.localhost]:2226'

rm -rf /tmp/repo_clone
rm -rf /tmp/confs-copy

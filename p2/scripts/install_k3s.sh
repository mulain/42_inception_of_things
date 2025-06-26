#!/bin/bash

set -e

echo "Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--node-ip=192.168.56.110 --flannel-iface=enp0s8 --write-kubeconfig-mode 644" sh -

echo "Waiting for K3s server to be active..."
until systemctl is-active --quiet k3s; do
    sleep 2
done

echo "Exporting KUBECONFIG..."
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "[INFO] Applying all settings in confs..."
kubectl apply -R -f /vagrant/confs/

echo "Done! Apps will soon (takes a while sometimes) be reachable via Host headers."
echo "Try: curl -H 'Host: app1.com' http://192.168.56.110"
echo "Also try with 'app2.com' and 'app3.com' as host headers."
echo "Finally, try a random host value, e.g. 'shmismshmang' - that should also go to app3."

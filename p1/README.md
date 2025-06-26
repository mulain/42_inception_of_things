# 🚧 Vagrant K3s Cluster Setup

Part 1 sets up a minimal two-node Kubernetes (K3s) cluster using [Vagrant](https://www.vagrantup.com/) and VirtualBox. It consists of:

- A **controller node** running the K3s server
- A **worker node** joining the controller via a shared token

### K3s
K3s is a lightweight Kubernetes distribution created by Rancher (now part of SUSE), designed to be:

- Simple to install
- Resource-efficient
- Ideal for development, edge computing, IoT, CI/CD, and small clusters

It’s basically Kubernetes at home.


## 📦 Requirements

- [VirtualBox](https://www.virtualbox.org/)
- [Vagrant](https://www.vagrantup.com/downloads)


## 📄 The Vagrantfile

The `Vagrantfile` defines and provisions two VMs:
- `npavelicS` – controller node (`192.168.56.110`)
- `kkwasnySW` – worker node (`192.168.56.111`)

The file has 2 parts:
1. Definitions
    - Basic variables
    - Provision scripts to be run after VM spin up
    - Array of 2 objects containing the settings for the 2 VMs (one object for each VM)
2. Applying the definitions
    - Set the VM provider
    - Set up each VM with the information from the object array
    - Specify `vm.network` as private network
    - Sync the current folder to each VM: this will enable sharing between VMs and inspecting the shared files from the host
    - Run the provisioning scripts


## 🏗️ Provisioning scripts

Though part of the `Vagrantfile`, these do the heavy lifting for setting up K3s and thus deserve their own section.

Both server and worker (also referred to as agent) install K3s using this line:

`curl -sfL https://get.k3s.io | [...] sh -`

- Downloads the official K3s installation script.

- Flags:
    - `-s` Silent mode (no progress bar).
    - `-f` Fail silently on HTTP errors.
    - `-L` Follow HTTP redirects.

- `|` pipes the curl return (which is the downloaded file) to stdout.

- `[...]` contains 
inline environment variable defintions such as `K3S_URL="..."`. These apply only to the command that immediately follows (`sh -`). See next section for more information on them.

- `sh -`: runs the command in stdout: executes the downloaded file and sets up th K3s machine using the inline env vars.

The server must also share the node token with the worker to allow it to join the cluster:
    
- `sudo chmod 777 /var/lib/rancher/k3s/server/node-token`: Prevents user-mismatch issues when copying `node-token`. The shell's user may not be the K3s installation's user and thus not have permission to manipulate the token.

- `sudo cp /var/lib/rancher/k3s/server/node-token /vagrant/node-token`: Copies `node-token` to the sync'd folder so the worker machine (and the host, just for observing) can access it.


### Env variables

#### For the server:
- `INSTALL_K3S_EXEC="--bind-address 192.168.56.110 --flannel-iface eth1 --write-kubeconfig-mode 644"`

    - `INSTALL_K3S_EXEC` contains flags passed to the install script

    - `--bind-address 192.168.56.110`
        - Sets the network interface address that the Kubernetes API server will bind to 
        - This must be an IP accessible from the worker nodes.
        - By default, K3s binds to 127.0.0.1, which is only accessible locally — so this is necessary for a multi-node setup.

    - `--flannel-iface eth1`
        - Specifies the network interface `Flannel` should use for inter-node pod networking. See section `Container Network Interface`.
        - In Vagrant VMs, eth1 corresponds to the private network interface which we are using.

#### For the worker:

- `K3S_URL="https://192.168.56.110:6443"`
    - Tells the install script where the K3s server is located:
        - ```192.168.56.110``` is the controller's IP address
        - ```:6443``` is the default Kubernetes API port
        - Without this, the script would try to set up this machine as a server, not a worker.

- `K3S_TOKEN="$(cat /vagrant/node-token)"`
    - Sets the cluster join token, which proves to the server that this node is allowed to join.
    - It reads the token from a shared file (/vagrant/node-token) that was written by the controller during its setup.

- `INSTALL_K3S_EXEC="--node-ip 192.168.56.111 --flannel-iface eth1"`
    - Additional flags passed to the install script to customize the worker setup.

    - `--node-ip 192.168.56.111`: Sets the worker's IP address that Kubernetes should advertise.

    - `--flannel-iface eth1`: Tells K3s to use eth1 for its flannel overlay networking interface (i.e. internal pod-to-pod traffic).


## 📡 Container Network Interface: Flannel

Container Network Interfaces (CNI) provide pod-to-pod networking across nodes by creating a virtual overlay network.

In this overlay, each node gets a virtual subnet, and pods communicate with each other using that network.

`Flannel` is a simple and popular CNI plugin for Kubernetes. We configure it using inline vars in the provisioning scripts.


## 🚀 Getting Started

To start the K3s cluster, run:

```bash
vagrant up
```

This will:

1. Launch both VMs

1. Install `K3s server` on the controller node

1. Write the controller’s node token to a shared folder

1. Install `K3s agent` on the worker

1. Join the worker node to the cluster using the node token


## 💻 Common Vagrant Commands

Some basic commands to work with Vagrant:

| Command                            | Description                                                  |
|------------------------------------|--------------------------------------------------------------|
| `vagrant up`                       | Creates and configures the VMs as defined in the Vagrantfile |
| `vagrant halt`                     | Gracefully shuts down all running VMs                        |
| `vagrant reload`                   | Restarts the VMs and applies any Vagrantfile changes         |
| `vagrant destroy`                  | Deletes all created VMs and removes their resources          |
| `vagrant status`                  | Shows the current status of all defined VMs                  |
| `vagrant ssh <vm-name>`           | Opens an SSH session into the specified VM                   |
| `vagrant provision <vm-name>`     | Re-runs the provisioning script on the specified VM          |
| `vagrant suspend`                 | Saves the current VM state and stops the VM                  |
| `vagrant resume`                  | Resumes a suspended VM                                       |


## 🔍 Cluster Access

To check cluster status from the controller:

```bash
vagrant ssh npavelicS
kubectl get nodes
```

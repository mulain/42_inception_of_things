# GitLab + ArgoCD Continuous Deployment Setup

This bonus section demonstrates a complete GitOps workflow using GitLab as the Git repository and ArgoCD for continuous deployment to Kubernetes. It builds upon the foundation established in the previous parts.

## Overview

The bonus setup creates a full CI/CD pipeline where:
- **GitLab** serves as the Git repository and provides a web interface
- **ArgoCD** monitors the GitLab repository and automatically deploys changes to Kubernetes
- **Kubernetes** runs the application using the same configuration patterns from previous parts

## Architecture

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   GitLab    │    │   ArgoCD    │    │ Kubernetes  │
│ Repository  │───▶│ Controller  │───▶│   Cluster   │
│             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
```

## Prerequisites

- Part 3 must be installed and running (k3d cluster with ArgoCD)
- Helm must be available (will be installed automatically if missing)
- SSH key pair for GitLab authentication

## Components

### GitLab Installation
- Lightweight GitLab instance using Helm
- Configured for local development with minimal resource usage
- Accessible at `http://gitlab.localhost:8081`
- SSH access on port 2226

### ArgoCD Integration
- Connects to GitLab repository via SSH
- Monitors configuration changes in the `confs/` directory
- Automatically syncs changes to Kubernetes cluster
- Web interface available at `http://localhost:8080`

### Application Deployment
- Uses the same `wil-playground` application from Part 3
- Deployed to `dev` namespace
- Exposed via NodePort service on port 30081 TODO:Check this

## Getting Started

### 1. Install GitLab
```bash
cd bonus/scripts
./install.sh
```

This will:
- Install Helm if not present
- Add GitLab Helm repository
- Create GitLab namespace
- Install GitLab with custom configuration
- Start port forwarding to localhost:8081
- Display the root password

### 2. Set up SSH Key
```bash
./create-ssh-key.sh
```

This creates an SSH key pair for GitLab authentication.

### 3. Configure GitLab
- Add the SSH key to the root account
- Create an empty repo named 'iot-bonus' TODO:Check

### 4. Configure ArgoCD with GitLab
```bash
./argocd-setup.sh
```

This script will:
- Ensure Part 3 is running
- Set up SSH port forwarding to GitLab
- Clone the repository and push configuration files
- Add the repository to ArgoCD
- Create the ArgoCD application
- Set up necessary RBAC permissions

## Configuration Files

### GitLab Configuration (`gitlab-values.yaml`)
- Minimal resource requirements for development
- Disabled unnecessary components (monitoring, registry, etc.)
- Configured for HTTP access on localhost

### Application Configuration (`confs/`)
- `deployment.yaml`: Kubernetes deployment for the application
- `service.yaml`: NodePort service exposing the application

## Access Points

- **GitLab Web UI**: http://gitlab.localhost:8081
  - Username: `root`
  - Password: Retrieved from install script

- **ArgoCD Web UI**: http://localhost:8080
  - Username: `admin`
  - Password: Retrieved from argocd-setup script

- **Application**: http://localhost:30081
  - Accessible after successful deployment

## GitOps Workflow

1. **Configuration Changes**: Modify files in `confs/` directory
2. **Git Push**: Changes are committed and pushed to GitLab
3. **ArgoCD Detection**: ArgoCD detects changes in the repository
4. **Automatic Sync**: ArgoCD applies changes to Kubernetes cluster
5. **Application Update**: New version is deployed automatically

## Troubleshooting

### Check Application Status
```bash
kubectl -n dev get svc,pods -o wide
```

### Check ArgoCD Application Status
```bash
argocd app get wil-playground-bonus
```

### View ArgoCD Logs
```bash
kubectl -n argocd logs -l app.kubernetes.io/name=argocd-application-controller
```

### Reset GitLab Repository
If the repository gets into an inconsistent state:
```bash
cd /tmp/repo_clone
git reset --hard HEAD
git clean -fd
```

## Cleanup

To remove the bonus setup:
```bash
./uninstall.sh
```

This will remove GitLab and clean up the ArgoCD application.

## Notes

- The setup uses minimal resource configurations suitable for development
- SSH authentication is used for secure GitLab-ArgoCD communication
- The application uses NodePort for simplicity; in production, consider using Ingress
- All passwords and secrets are automatically generated and displayed during setup 
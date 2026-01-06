# Cluster Deploy Pipelines

This Helm chart provides OpenShift Pipelines (Tekton) for deploying OpenShift clusters using ACM (Advanced Cluster Management) and Hive, replacing the Ansible Automation Platform workflow.

## Overview

The chart includes:
- **Tekton Tasks**: Individual tasks for each step of cluster deployment
- **Pipeline**: Orchestrates all tasks in the correct order
- **ServiceAccount & RBAC**: Required permissions for cluster operations
- **PipelineRun Templates**: Examples for user submission

## Prerequisites

- OpenShift cluster with Tekton Pipelines installed
- ACM (Advanced Cluster Management) and Hive operators installed
- External Secrets Operator installed
- ClusterSecretStore configured (default: `vault-backend`)
- Provider credentials stored in Vault at:
  - `secret/data/hub/aws` (for AWS)
  - `secret/data/hub/gcp` (for GCP)
  - `secret/data/hub/azure` (for Azure)
  - `pushsecrets/global-pull-secret` (for pull secret)

## Installation

Install the chart:

```bash
helm install cluster-deploy-pipelines ./charts/hub/cluster-deploy-pipelines \
  --namespace openshift-pipelines \
  --create-namespace
```

### Workspace PVCs

The pipeline requires two workspaces for sharing content between tasks:
- `install-config`: Stores install-config.yaml
- `kubeconfig`: Stores cluster kubeconfig

**Option 1: Shared PVCs (Recommended for multiple pipeline runs)**

Create shared PVCs that can be reused across pipeline runs:

```bash
helm install cluster-deploy-pipelines ./charts/hub/cluster-deploy-pipelines \
  --namespace openshift-pipelines \
  --create-namespace \
  --set workspaces.createPVCs=true \
  --set workspaces.installConfig.storageSize=2Gi \
  --set workspaces.kubeconfig.storageSize=2Gi
```

Then reference them in PipelineRun:
```yaml
workspaces:
- name: install-config
  persistentVolumeClaim:
    claimName: cluster-deploy-pipelines-install-config
- name: kubeconfig
  persistentVolumeClaim:
    claimName: cluster-deploy-pipelines-kubeconfig
```

**Option 2: Per-Run PVCs (Default)**

Each PipelineRun creates its own PVCs using `volumeClaimTemplate` (default behavior). See examples for this approach.

## Usage

### Method 1: Using PipelineRun in OpenShift Console

1. Navigate to **Pipelines** → **PipelineRuns** → **Create**
2. Select the `deploy-cluster` pipeline
3. Fill in the required parameters:
   - `cluster-name`: Name of your cluster
   - `base-domain`: Base domain for the cluster
   - `cloud-provider`: One of `Amazon`, `Google`, or `Azure`
   - `cloud-region`: Cloud region (e.g., `us-east-1`, `us-central1`, `eastus`)
   - `cluster-version`: Image set name (check with `oc get clusterimageset`)
   - `control-plane-machine-type`: Machine type for control plane nodes
   - `worker-machine-type`: Machine type for worker nodes
4. Optionally configure:
   - `cluster-group`: Cluster group label (default: `devops`)
   - `control-plane-replicas`: Number of control plane nodes (default: `3`)
   - `worker-replicas`: Number of worker nodes (default: `3`)
   - `azure-resource-group`: Required for Azure deployments
   - `gcp-project-id`: Required for GCP deployments
   - `ssh-public-key`: Optional SSH public key
   - `secret-store-name`: ClusterSecretStore name (default: `vault-backend`)
   - `aws-creds-key-path`: Vault path for AWS credentials (default: `secret/data/hub/aws`)
   - `gcp-creds-key-path`: Vault path for GCP credentials (default: `secret/data/hub/gcp`)
   - `azure-creds-key-path`: Vault path for Azure credentials (default: `secret/data/hub/azure`)
   - `pullsecret-key-path`: Vault path for pull secret (default: `pushsecrets/global-pull-secret`)
   - `timeout-minutes`: Timeout for cluster deployment (default: `90`)
5. Click **Create** to start the pipeline

### Method 2: Using PipelineRun YAML

Create a PipelineRun YAML file based on the examples:

```bash
# For AWS (with per-run PVCs)
oc apply -f charts/hub/cluster-deploy-pipelines/examples/pipelinerun-aws.yaml

# For AWS (with shared PVCs)
oc apply -f charts/hub/cluster-deploy-pipelines/examples/pipelinerun-aws-shared-pvc.yaml

# For GCP
oc apply -f charts/hub/cluster-deploy-pipelines/examples/pipelinerun-gcp.yaml

# For Azure
oc apply -f charts/hub/cluster-deploy-pipelines/examples/pipelinerun-azure.yaml
```

Edit the file to customize parameters before applying.

**Note:** If using shared PVCs, ensure they are created first (see Installation section).

### Method 3: Git-based Submission

1. Create a cluster configuration ConfigMap (see `examples/cluster-config-form.yaml`)
2. Fill in the required fields
3. Apply the ConfigMap:
   ```bash
   oc apply -f examples/cluster-config-form.yaml
   ```
4. Generate and apply PipelineRun using the helper script:
   ```bash
   ./scripts/generate-pipelinerun.sh cluster-config-form | oc apply -f -
   ```
   
   Or commit the ConfigMap to Git and use a webhook/automation tool to trigger the script.

## Pipeline Tasks

The pipeline executes the following tasks in order:

1. **create-namespace**: Creates the namespace for the cluster
2. **create-externalsecrets**: Creates ExternalSecret objects that sync provider credentials and pull secret from Vault
3. **create-install-config**: Generates and creates the install-config secret
4. **create-cluster-deployment**: Creates the ClusterDeployment resource
5. **create-machinepool**: Creates MachinePool for AWS worker nodes (skipped for GCP/Azure)
6. **wait-cluster-ready**: Waits for cluster deployment and extracts kubeconfig
7. **create-managed-cluster**: Creates the ManagedCluster resource
8. **create-import-secret**: Creates auto-import secret for ACM
9. **create-klusterlet-addon**: Creates KlusterletAddonConfig resource

## Monitoring

Monitor the pipeline execution:

```bash
# Watch pipeline run status
oc get pipelinerun -n openshift-pipelines -w

# View pipeline logs
tkn pipelinerun logs -n openshift-pipelines <pipelinerun-name>

# Check cluster deployment status
oc get clusterdeployment -n <cluster-name>
oc get managedcluster <cluster-name>
```

## Troubleshooting

### Pipeline fails at create-externalsecrets task

- Ensure External Secrets Operator is installed and running
- Verify ClusterSecretStore exists and is properly configured
- Check that credentials exist in Vault at the specified paths
- Verify ExternalSecret objects were created: `oc get externalsecrets -n <cluster-name>`
- Check ExternalSecret status: `oc describe externalsecret eso-aws-creds -n <cluster-name>`

### Cluster deployment fails

- Check ClusterDeployment status: `oc describe clusterdeployment <cluster-name> -n <cluster-name>`
- Review installer pod logs: `oc logs -l hive.openshift.io/cluster-deployment-name=<cluster-name> -n <cluster-name>`
- Verify install-config secret is correct: `oc get secret <cluster-name>-install-config -n <cluster-name> -o yaml`

### ManagedCluster not importing

- Verify auto-import-secret exists: `oc get secret auto-import-secret -n <cluster-name>`
- Check ManagedCluster status: `oc get managedcluster <cluster-name>`
- Review KlusterletAddonConfig: `oc get klusterletaddonconfig <cluster-name> -n <cluster-name>`

## Configuration

### Values

| Key | Description | Default |
|-----|-------------|---------|
| `serviceAccount.name` | ServiceAccount name | `cluster-deploy-pipelines-sa` |
| `serviceAccount.namespace` | ServiceAccount namespace | `openshift-pipelines` |
| `kubectlImage` | Image for kubectl/oc commands | `quay.io/openshift/origin-cli:latest` |
| `workspaces.createPVCs` | Create shared PVCs via Helm | `false` |
| `workspaces.installConfig.storageSize` | Size of install-config PVC | `1Gi` |
| `workspaces.installConfig.storageClassName` | Storage class for install-config PVC | `""` (default) |
| `workspaces.kubeconfig.storageSize` | Size of kubeconfig PVC | `1Gi` |
| `workspaces.kubeconfig.storageClassName` | Storage class for kubeconfig PVC | `""` (default) |

## Migration from Ansible

This pipeline replaces the Ansible Automation Platform workflow. The equivalent Ansible variables map to PipelineRun parameters:

| Ansible Variable | PipelineRun Parameter |
|-----------------|----------------------|
| `cluster_name` | `cluster-name` |
| `cluster_base_domain` | `base-domain` |
| `cloud_provider` | `cloud-provider` |
| `cloud_region` | `cloud-region` |
| `cluster.version` | `cluster-version` |
| `machinePools.controlPlane.machineType` | `control-plane-machine-type` |
| `machinePools.workers.machineType` | `worker-machine-type` |
| `machinePools.controlPlane.replicas` | `control-plane-replicas` |
| `machinePools.workers.replicas` | `worker-replicas` |
| `cloudConfig.azure.baseDomainResourceGroupName` | `azure-resource-group` |
| `cloudConfig.gcp.projectID` | `gcp-project-id` |
| `cluster.clusterGroup` | `cluster-group` |

**Note:** The pipeline now uses External Secrets Operator instead of copying secrets. Credentials are synced from Vault using ExternalSecret objects.

## Helper Scripts

### generate-pipelinerun.sh

Converts a ConfigMap containing cluster configuration into a PipelineRun YAML.

**Usage:**
```bash
./scripts/generate-pipelinerun.sh <configmap-name> [namespace] [pipeline-name] [service-account]
```

**Example:**
```bash
# Generate PipelineRun from ConfigMap
./scripts/generate-pipelinerun.sh cluster-config-form | oc apply -f -

# Or save to file first
./scripts/generate-pipelinerun.sh cluster-config-form > my-pipelinerun.yaml
oc apply -f my-pipelinerun.yaml
```

## Quick Reference

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `cluster-name` | Name of the cluster | `my-cluster` |
| `base-domain` | Base domain | `example.com` |
| `cloud-provider` | Provider (Amazon/Google/Azure) | `Amazon` |
| `cloud-region` | Cloud region | `us-east-1` |
| `cluster-version` | Image set name | `img4.19.9-x86-64-appsub` |
| `control-plane-machine-type` | Control plane instance type | `m5.xlarge` |
| `worker-machine-type` | Worker instance type | `m5.4xlarge` |

### Optional Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `cluster-group` | `devops` | Cluster group label |
| `control-plane-replicas` | `3` | Number of control plane nodes |
| `worker-replicas` | `3` | Number of worker nodes |
| `azure-resource-group` | `""` | Required for Azure |
| `gcp-project-id` | `""` | Required for GCP |
| `ssh-public-key` | `""` | SSH public key |
| `use-shared-credentials` | `true` | Use shared credentials |
| `timeout-minutes` | `90` | Deployment timeout |

### Common Machine Types

**AWS:**
- Control Plane: `m5.xlarge`, `m5.2xlarge`
- Workers: `m5.4xlarge`, `m5.8xlarge`

**GCP:**
- Control Plane: `n1-standard-4`, `n1-standard-8`
- Workers: `n1-standard-8`, `n1-standard-16`

**Azure:**
- Control Plane: `Standard_D8s_v3`, `Standard_D16s_v3`
- Workers: `Standard_D16s_v3`, `Standard_D32s_v3`

## License

BSD

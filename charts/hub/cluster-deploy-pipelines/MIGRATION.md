# Migration Guide: Ansible Automation Platform to OpenShift Pipelines

This document outlines the migration from Ansible Automation Platform (AAP) to OpenShift Pipelines for cluster deployment.

## What Was Created

### Helm Chart: `cluster-deploy-pipelines`

A complete Helm chart that replaces the AAP workflow with Tekton Pipelines.

**Location:** `charts/hub/cluster-deploy-pipelines/`

### Components

1. **Tekton Tasks** (9 tasks):
   - `create-namespace`: Creates namespace for cluster
   - `copy-provider-secrets`: Copies credentials from hive namespace
   - `create-install-config`: Generates install-config secret
   - `create-cluster-deployment`: Creates ClusterDeployment resource
   - `create-machinepool`: Creates MachinePool for AWS workers
   - `wait-cluster-ready`: Waits for cluster and extracts kubeconfig
   - `create-managed-cluster`: Creates ManagedCluster resource
   - `create-import-secret`: Creates auto-import secret
   - `create-klusterlet-addon`: Creates KlusterletAddonConfig

2. **Pipeline**: `deploy-cluster`
   - Orchestrates all tasks in the correct order
   - Handles conditional execution (e.g., MachinePool only for AWS)

3. **RBAC**: ServiceAccount with required permissions
   - ClusterRole and RoleBindings for cluster operations
   - Permissions for namespaces, secrets, ClusterDeployments, ManagedClusters, etc.

4. **Examples**:
   - PipelineRun examples for AWS, GCP, and Azure
   - ConfigMap form template for git-based submission
   - Helper script to convert ConfigMap to PipelineRun

## Installation

```bash
# Install the chart
helm install cluster-deploy-pipelines ./charts/hub/cluster-deploy-pipelines \
  --namespace openshift-pipelines \
  --create-namespace
```

## Usage Comparison

### Before (AAP)

1. User submits form in AAP console
2. AAP JobTemplate runs Ansible playbook
3. Playbook executes tasks sequentially
4. Resources created via Ansible k8s module

### After (OpenShift Pipelines)

**Option 1: OpenShift Console**
1. User creates PipelineRun in OpenShift Console
2. Pipeline executes Tekton Tasks
3. Resources created via kubectl/oc commands

**Option 2: YAML File**
1. User creates PipelineRun YAML
2. Applies via `oc apply -f pipelinerun.yaml`
3. Pipeline executes automatically

**Option 3: Git-based**
1. User commits ConfigMap with cluster config
2. Webhook/automation triggers helper script
3. Script generates PipelineRun
4. Pipeline executes automatically

## Parameter Mapping

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
| `user_provided_credentials` | `use-shared-credentials` (inverted) |

## Benefits

1. **Native Integration**: Uses OpenShift Pipelines (Tekton) - no external dependencies
2. **GitOps Friendly**: Easy to integrate with Git-based workflows
3. **Better Visibility**: Pipeline runs visible in OpenShift Console
4. **Simpler RBAC**: Uses standard Kubernetes RBAC
5. **No AAP Dependency**: Removes dependency on Ansible Automation Platform

## Next Steps

1. **Test the Pipeline**: Deploy a test cluster using one of the examples
2. **Update Documentation**: Update any user-facing documentation
3. **Set up Webhooks** (optional): Configure Git webhooks to auto-trigger pipelines
4. **Monitor**: Set up monitoring/alerts for pipeline failures
5. **Deprecate AAP**: Once validated, remove AAP JobTemplate

## Rollback Plan

If needed, you can continue using AAP by:
1. Keeping the AAP JobTemplate active
2. Using AAP for cluster deployments
3. Gradually migrating clusters to Pipelines

Both systems can coexist during migration.

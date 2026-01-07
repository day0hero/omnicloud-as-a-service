# Quick Start: Destroy Cluster

This guide shows you how to quickly destroy a provisioned cluster.

## Prerequisites

- Cluster must exist
- Service account has delete permissions (included by default)

## Quick Destroy

```bash
# Replace "my-cluster" with your cluster name
oc apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: destroy-my-cluster
  namespace: openshift-pipelines
spec:
  pipelineRef:
    name: destroy-cluster
  serviceAccountName: pipeline
  params:
  - name: cluster-name
    value: "my-cluster"
  workspaces:
  - name: namespace-info
    emptyDir: {}
EOF
```

## Monitor Destruction

```bash
# Watch PipelineRun
oc get pipelinerun destroy-my-cluster -n openshift-pipelines -w

# View logs
tkn pipelinerun logs destroy-my-cluster -n openshift-pipelines -f
```

## Destroy from ConfigMap

If you have a ConfigMap with cluster configuration:

```bash
# Extract cluster name
CLUSTER_NAME=$(oc get configmap cluster-config-form-example -n openshift-pipelines -o jsonpath='{.data.cluster-name}')

# Destroy cluster
oc apply -f - <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: destroy-$CLUSTER_NAME
  namespace: openshift-pipelines
spec:
  pipelineRef:
    name: destroy-cluster
  serviceAccountName: pipeline
  params:
  - name: cluster-name
    value: "$CLUSTER_NAME"
  workspaces:
  - name: namespace-info
    emptyDir: {}
EOF
```

## Options

### Keep Namespace

To destroy cluster but keep the namespace:

```yaml
params:
- name: delete-namespace
  value: "false"
```

### Extended Timeout

For large clusters or slow cloud providers:

```yaml
params:
- name: timeout-minutes
  value: "60"
```

## What Gets Deleted

1. **ClusterDeployment** - Triggers infrastructure deletion
2. **ManagedCluster** - Removes from ACM
3. **ExternalSecrets** - Removes credential sync
4. **Secrets** - Removes cluster secrets
5. **MachinePools** - Removes worker node pools
6. **KlusterletAddonConfigs** - Removes addon configuration
7. **Namespace** - Removes cluster namespace (optional)

## Troubleshooting

### Cluster Not Found

If cluster doesn't exist, the pipeline will skip deletion gracefully.

### Namespace Won't Delete

Check for finalizers:
```bash
oc get namespace <cluster-name> -o yaml | grep finalizers
```

### Permission Errors

Upgrade the Helm chart to get delete permissions:
```bash
helm upgrade cluster-deploy-pipelines ./charts/hub/cluster-deploy-pipelines --namespace openshift-pipelines
```

## See Also

- [DESTROY_CLUSTER.md](../DESTROY_CLUSTER.md) - Complete documentation
- [README.md](../README.md) - Pipeline overview

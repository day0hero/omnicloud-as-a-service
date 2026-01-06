#!/bin/bash
# Script to generate PipelineRun from cluster-config-form ConfigMap
# Usage: ./generate-pipelinerun.sh <configmap-name> [namespace]

set -e

CONFIGMAP_NAME=${1:-cluster-config-form}
NAMESPACE=${2:-openshift-pipelines}
PIPELINE_NAME=${3:-deploy-cluster}
SERVICE_ACCOUNT=${4:-cluster-deploy-pipelines-sa}

if ! oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &>/dev/null; then
  echo "Error: ConfigMap $CONFIGMAP_NAME not found in namespace $NAMESPACE"
  exit 1
fi

# Extract values from ConfigMap
CLUSTER_NAME=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cluster-name}')
BASE_DOMAIN=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.base-domain}')
CLOUD_PROVIDER=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cloud-provider}')
CLOUD_REGION=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cloud-region}')
CLUSTER_VERSION=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cluster-version}')
CP_MACHINE_TYPE=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.control-plane-machine-type}')
WORKER_MACHINE_TYPE=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.worker-machine-type}')
CLUSTER_GROUP=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.cluster-group}')
CP_REPLICAS=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.control-plane-replicas}')
WORKER_REPLICAS=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.worker-replicas}')
AZURE_RG=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.azure-resource-group}')
GCP_PROJECT=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.gcp-project-id}')
SSH_KEY=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.ssh-public-key}')
SECRET_STORE=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.secret-store-name}')
AWS_KEY=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.aws-creds-key-path}')
GCP_KEY=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.gcp-creds-key-path}')
AZURE_KEY=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.azure-creds-key-path}')
PULLSECRET_KEY=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.pullsecret-key-path}')
TIMEOUT=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.timeout-minutes}')
SERVICE_ACCOUNT_FROM_CM=$(oc get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o jsonpath='{.data.service-account-name}' 2>/dev/null || echo "")

# Validate required fields
if [ -z "$CLUSTER_NAME" ] || [ -z "$BASE_DOMAIN" ] || [ -z "$CLOUD_PROVIDER" ] || \
   [ -z "$CLOUD_REGION" ] || [ -z "$CLUSTER_VERSION" ] || [ -z "$CP_MACHINE_TYPE" ] || \
   [ -z "$WORKER_MACHINE_TYPE" ]; then
  echo "Error: Required fields are missing in ConfigMap"
  echo "Required: cluster-name, base-domain, cloud-provider, cloud-region, cluster-version, control-plane-machine-type, worker-machine-type"
  exit 1
fi

# Set defaults
CLUSTER_GROUP=${CLUSTER_GROUP:-devops}
CP_REPLICAS=${CP_REPLICAS:-3}
WORKER_REPLICAS=${WORKER_REPLICAS:-3}
SECRET_STORE=${SECRET_STORE:-vault-backend}
AWS_KEY=${AWS_KEY:-secret/data/hub/aws}
GCP_KEY=${GCP_KEY:-secret/data/hub/gcp}
AZURE_KEY=${AZURE_KEY:-secret/data/hub/azure}
PULLSECRET_KEY=${PULLSECRET_KEY:-pushsecrets/global-pull-secret}
TIMEOUT=${TIMEOUT:-90}
# Use serviceAccountName from ConfigMap if provided, otherwise use script parameter or default
SERVICE_ACCOUNT=${SERVICE_ACCOUNT_FROM_CM:-$SERVICE_ACCOUNT}

# Generate unique PipelineRun name
TIMESTAMP=$(date +%s)
PIPELINERUN_NAME="deploy-cluster-${CLUSTER_NAME}-${TIMESTAMP}"

# Generate PipelineRun YAML
cat <<EOF
apiVersion: tekton.dev/v1beta1
kind: PipelineRun
metadata:
  name: $PIPELINERUN_NAME
  namespace: $NAMESPACE
spec:
  pipelineRef:
    name: $PIPELINE_NAME
  serviceAccountName: $SERVICE_ACCOUNT
  params:
  - name: cluster-name
    value: "$CLUSTER_NAME"
  - name: base-domain
    value: "$BASE_DOMAIN"
  - name: cloud-provider
    value: "$CLOUD_PROVIDER"
  - name: cloud-region
    value: "$CLOUD_REGION"
  - name: cluster-version
    value: "$CLUSTER_VERSION"
  - name: control-plane-machine-type
    value: "$CP_MACHINE_TYPE"
  - name: worker-machine-type
    value: "$WORKER_MACHINE_TYPE"
  - name: cluster-group
    value: "$CLUSTER_GROUP"
  - name: control-plane-replicas
    value: "$CP_REPLICAS"
  - name: worker-replicas
    value: "$WORKER_REPLICAS"
EOF

# Add optional parameters if set
if [ -n "$AZURE_RG" ]; then
  echo "  - name: azure-resource-group"
  echo "    value: \"$AZURE_RG\""
fi

if [ -n "$GCP_PROJECT" ]; then
  echo "  - name: gcp-project-id"
  echo "    value: \"$GCP_PROJECT\""
fi

if [ -n "$SSH_KEY" ]; then
  echo "  - name: ssh-public-key"
  echo "    value: \"$SSH_KEY\""
fi

cat <<EOF
  - name: secret-store-name
    value: "$SECRET_STORE"
  - name: aws-creds-key-path
    value: "$AWS_KEY"
  - name: gcp-creds-key-path
    value: "$GCP_KEY"
  - name: azure-creds-key-path
    value: "$AZURE_KEY"
  - name: pullsecret-key-path
    value: "$PULLSECRET_KEY"
  - name: timeout-minutes
    value: "$TIMEOUT"
  workspaces:
  - name: install-config
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
  - name: kubeconfig
    volumeClaimTemplate:
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Gi
EOF

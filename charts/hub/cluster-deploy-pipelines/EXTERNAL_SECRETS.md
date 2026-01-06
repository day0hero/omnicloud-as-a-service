# External Secrets Integration

This document describes how the cluster deployment pipeline uses External Secrets Operator (ESO) instead of copying secrets.

## Overview

The pipeline now uses External Secrets Operator to sync provider credentials and pull secrets from Vault directly into the cluster namespace, eliminating the need to copy secrets from the `hive` namespace.

## Architecture

### Before (Secret Copying)
1. Secrets stored in `hive` namespace
2. Pipeline copies secrets to target namespace
3. Secrets are static copies

### After (External Secrets)
1. Secrets stored in Vault
2. ExternalSecret objects created in target namespace
3. External Secrets Operator syncs secrets automatically
4. Secrets are kept in sync with Vault

## ExternalSecret Objects

The pipeline creates ExternalSecret objects based on the cloud provider:

### AWS ExternalSecret
- **Name**: `eso-aws-creds`
- **Target Secret**: `aws-creds`
- **Vault Path**: `secret/data/hub/aws` (configurable)
- **Type**: Opaque (extracts all data from Vault)

### GCP ExternalSecret
- **Name**: `eso-gcp-creds`
- **Target Secret**: `gcp-creds`
- **Vault Path**: `secret/data/hub/gcp` (configurable)
- **Type**: Opaque
- **Template**: Transforms Vault content to `osServiceAccount.json`

### Azure ExternalSecret
- **Name**: `eso-azure-creds`
- **Target Secret**: `azure-creds`
- **Vault Path**: `secret/data/hub/azure` (configurable)
- **Type**: Opaque
- **Template**: Transforms Vault content to `osServicePrincipal.json`

### Pull Secret ExternalSecret
- **Name**: `global-pullsecret`
- **Target Secret**: `global-pullsecret`
- **Vault Path**: `pushsecrets/global-pull-secret` (configurable)
- **Type**: kubernetes.io/dockerconfigjson
- **Property**: Extracts `docker` property from Vault

## Configuration

### Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `secret-store-name` | `vault-backend` | Name of the ClusterSecretStore |
| `aws-creds-key-path` | `secret/data/hub/aws` | Vault path for AWS credentials |
| `gcp-creds-key-path` | `secret/data/hub/gcp` | Vault path for GCP credentials |
| `azure-creds-key-path` | `secret/data/hub/azure` | Vault path for Azure credentials |
| `pullsecret-key-path` | `pushsecrets/global-pull-secret` | Vault path for pull secret |

### ClusterSecretStore

The pipeline expects a ClusterSecretStore named `vault-backend` (or as specified in `secret-store-name`). This ClusterSecretStore should be configured to connect to your Vault instance.

Example ClusterSecretStore:
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-backend
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "external-secrets"
          serviceAccountRef:
            name: external-secrets-sa
```

## Task: create-externalsecrets

The `create-externalsecrets` task replaces the old `copy-provider-secrets` task. It:

1. Creates ExternalSecret objects based on the cloud provider
2. Waits for External Secrets Operator to sync the secrets
3. Verifies that target secrets were created

### Task Flow

1. **Create Provider ExternalSecret**: Creates AWS, GCP, or Azure ExternalSecret based on `cloud-provider` parameter
2. **Create Pull Secret ExternalSecret**: Always creates pull secret ExternalSecret
3. **Wait for Sync**: Waits up to 60 seconds for secrets to be created
4. **Verify**: Checks that required secrets exist before proceeding

## Benefits

1. **Automatic Sync**: Secrets are automatically synced from Vault
2. **No Manual Copying**: Eliminates the need to copy secrets between namespaces
3. **Centralized Management**: All secrets managed in Vault
4. **Rotation Support**: External Secrets Operator can handle secret rotation
5. **Audit Trail**: Better visibility into secret access via External Secrets

## Troubleshooting

### ExternalSecret Not Syncing

1. Check ExternalSecret status:
   ```bash
   oc describe externalsecret eso-aws-creds -n <cluster-name>
   ```

2. Verify ClusterSecretStore exists:
   ```bash
   oc get clustersecretstore vault-backend
   ```

3. Check External Secrets Operator logs:
   ```bash
   oc logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets
   ```

### Secret Not Created

1. Verify ExternalSecret was created:
   ```bash
   oc get externalsecrets -n <cluster-name>
   ```

2. Check ExternalSecret conditions:
   ```bash
   oc get externalsecret eso-aws-creds -n <cluster-name> -o yaml
   ```

3. Verify Vault path exists and is accessible

### Wrong Secret Format

- For GCP/Azure: Ensure Vault stores the content in a `content` property
- For AWS: Ensure Vault stores credentials in the expected format
- For pull secret: Ensure Vault stores docker config in `docker` property

## Migration Notes

When migrating from secret copying to External Secrets:

1. **Remove old secrets**: Delete copied secrets from cluster namespaces
2. **Create ExternalSecrets**: Pipeline will create them automatically
3. **Verify sync**: Ensure External Secrets Operator syncs correctly
4. **Update documentation**: Update any documentation referencing secret copying

## References

- [External Secrets Operator Documentation](https://external-secrets.io/)
- [ClusterSecretStore API](https://external-secrets.io/v0.9.0/api/clustersecretstore/)
- [ExternalSecret API](https://external-secrets.io/v0.9.0/api/externalsecret/)

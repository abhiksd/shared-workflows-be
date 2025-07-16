# Azure Key Vault Integration

## Overview

This document describes the Azure Key Vault integration for securely managing application secrets, database credentials, third-party API tokens, and other sensitive configuration data.

## Integration Features

### 🔐 Automated Secret Retrieval
- Retrieves secrets from Azure Key Vault using managed identity
- Converts secrets to Kubernetes secrets automatically
- Supports environment-specific secret isolation
- No hardcoded credentials in code or configuration

### 📋 Secret Categories Supported
- **Database credentials**: Username, password, connection strings
- **Application secrets**: JWT secrets, encryption keys, API keys
- **Third-party integrations**: External API URLs, tokens, webhook secrets
- **Storage**: Azure Storage account keys, connection strings
- **Messaging**: Service Bus, Redis connection strings
- **Monitoring**: Application Insights keys, logging endpoints

## Secret Naming Convention

### Pattern
```
{application-name}-{environment}-{secret-type}
```

### Examples
```bash
# Database secrets
java-app-dev-db-username
java-app-dev-db-password
java-app-dev-db-connection-string

# Application secrets
java-app-prod-jwt-secret
java-app-staging-encryption-key
nodejs-app-dev-api-key

# Third-party integrations
java-app-prod-external-api-url
java-app-prod-external-api-token
nodejs-app-dev-webhook-secret

# Storage secrets
java-app-prod-storage-account-key
java-app-dev-storage-connection-string

# Messaging secrets
java-app-prod-servicebus-connection-string
nodejs-app-dev-redis-connection-string

# Monitoring secrets
java-app-prod-appinsights-key
java-app-staging-logging-connection-string

# Shared environment secrets
dev-shared-secret
prod-common-api-key
```

## Setup Instructions

### 1. Create Azure Key Vault

```bash
# Set variables
RESOURCE_GROUP="your-resource-group"
KEYVAULT_NAME="your-keyvault-name"
LOCATION="eastus"

# Create Key Vault
az keyvault create \
  --name $KEYVAULT_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --enable-rbac-authorization true
```

### 2. Configure Key Vault Permissions

The managed identity used by your GitHub runners needs the following role:

```bash
# Get the managed identity object ID
MANAGED_IDENTITY_ID="your-managed-identity-object-id"

# Assign Key Vault Secrets User role
az role assignment create \
  --role "Key Vault Secrets User" \
  --assignee $MANAGED_IDENTITY_ID \
  --scope "/subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.KeyVault/vaults/{keyvault-name}"
```

### 3. Add Repository Secret

Add the following secret to your GitHub repository:
- `KEYVAULT_NAME`: Your Azure Key Vault name

### 4. Populate Key Vault with Secrets

Use the provided script or Azure CLI to add secrets:

```bash
# Example: Add database credentials for java-app dev environment
az keyvault secret set --vault-name $KEYVAULT_NAME --name "java-app-dev-db-username" --value "dev_user"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "java-app-dev-db-password" --value "dev_password123"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "java-app-dev-db-host" --value "dev-postgres.database.azure.com"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "java-app-dev-db-port" --value "5432"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "java-app-dev-db-name" --value "java_app_dev"
```

## Application Integration

### Environment Variables

Secrets are automatically injected as environment variables in your application containers:

```bash
# Database configuration
JAVA_APP_DEV_DB_USERNAME=dev_user
JAVA_APP_DEV_DB_PASSWORD=dev_password123
JAVA_APP_DEV_DB_HOST=dev-postgres.database.azure.com
JAVA_APP_DEV_DB_PORT=5432
JAVA_APP_DEV_DB_NAME=java_app_dev

# Application secrets
JAVA_APP_DEV_JWT_SECRET=your-jwt-secret
JAVA_APP_DEV_ENCRYPTION_KEY=your-encryption-key

# External API configuration
JAVA_APP_DEV_EXTERNAL_API_URL=https://api.example.com
JAVA_APP_DEV_EXTERNAL_API_TOKEN=your-api-token
```

### Spring Boot Application Example

```yaml
# application-dev.yml
spring:
  datasource:
    url: jdbc:postgresql://${JAVA_APP_DEV_DB_HOST}:${JAVA_APP_DEV_DB_PORT}/${JAVA_APP_DEV_DB_NAME}
    username: ${JAVA_APP_DEV_DB_USERNAME}
    password: ${JAVA_APP_DEV_DB_PASSWORD}

jwt:
  secret: ${JAVA_APP_DEV_JWT_SECRET}

external:
  api:
    url: ${JAVA_APP_DEV_EXTERNAL_API_URL}
    token: ${JAVA_APP_DEV_EXTERNAL_API_TOKEN}
```

### Node.js Application Example

```javascript
// config.js
module.exports = {
  database: {
    host: process.env.NODEJS_APP_DEV_DB_HOST,
    port: process.env.NODEJS_APP_DEV_DB_PORT,
    database: process.env.NODEJS_APP_DEV_DB_NAME,
    username: process.env.NODEJS_APP_DEV_DB_USERNAME,
    password: process.env.NODEJS_APP_DEV_DB_PASSWORD
  },
  jwt: {
    secret: process.env.NODEJS_APP_DEV_JWT_SECRET
  },
  external: {
    api: {
      url: process.env.NODEJS_APP_DEV_EXTERNAL_API_URL,
      token: process.env.NODEJS_APP_DEV_EXTERNAL_API_TOKEN
    }
  }
};
```

## Helm Chart Integration

### Values File Configuration

The Helm chart automatically configures secret injection:

```yaml
# Values file snippet
secrets:
  enabled: true
  existingSecret: java-app-dev-secrets

envFrom:
  - secretRef:
      name: java-app-dev-secrets
      optional: true

database:
  enabled: true
  type: postgresql
  # Connection details come from environment variables

externalApis:
  enabled: true
  # API configuration comes from environment variables
```

### Deployment Template

```yaml
# deployment.yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: {{ .Values.nameOverride }}
        envFrom:
        {{- if .Values.secrets.enabled }}
        - secretRef:
            name: {{ .Values.secrets.existingSecret }}
            optional: true
        {{- end }}
```

## Security Best Practices

### 1. Secret Rotation
- Regularly rotate secrets, especially for production environments
- Use Azure Key Vault's versioning feature for rollback capability
- Implement automated rotation where possible

### 2. Access Control
- Use least privilege principle for managed identity permissions
- Separate Key Vaults for different environments if required
- Enable auditing and monitoring on Key Vault access

### 3. Environment Isolation
- Use different secret names for each environment
- Consider separate Key Vaults for production vs non-production
- Implement proper approval workflows for production secret changes

## Management Scripts

### Add Multiple Secrets

```bash
#!/bin/bash
# add-app-secrets.sh
KEYVAULT_NAME="your-keyvault"
APP_NAME="java-app"
ENVIRONMENT="dev"

# Database secrets
az keyvault secret set --vault-name $KEYVAULT_NAME --name "${APP_NAME}-${ENVIRONMENT}-db-username" --value "dev_user"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "${APP_NAME}-${ENVIRONMENT}-db-password" --value "$(openssl rand -base64 32)"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "${APP_NAME}-${ENVIRONMENT}-db-host" --value "dev-postgres.database.azure.com"

# Application secrets
az keyvault secret set --vault-name $KEYVAULT_NAME --name "${APP_NAME}-${ENVIRONMENT}-jwt-secret" --value "$(openssl rand -base64 64)"
az keyvault secret set --vault-name $KEYVAULT_NAME --name "${APP_NAME}-${ENVIRONMENT}-encryption-key" --value "$(openssl rand -base64 32)"
```

### List Application Secrets

```bash
#!/bin/bash
# list-app-secrets.sh
KEYVAULT_NAME="your-keyvault"
APP_NAME="java-app"
ENVIRONMENT="dev"

echo "Secrets for ${APP_NAME}-${ENVIRONMENT}:"
az keyvault secret list --vault-name $KEYVAULT_NAME --query "[?starts_with(name, '${APP_NAME}-${ENVIRONMENT}')].{Name:name, Updated:attributes.updated}" -o table
```

## Monitoring and Troubleshooting

### Key Vault Access Logs

Monitor Key Vault access in Azure Monitor:

```kusto
KeyVaultData
| where ResourceType == "MICROSOFT.KEYVAULT/VAULTS"
| where OperationName == "SecretGet"
| where ResultSignature == "OK"
| project TimeGenerated, CallerIpAddress, identity_claim_appid_g, SecretName = extract(@'/secrets/([^/]+)', 1, requestUri_s)
```

### Common Issues

1. **Access Denied**: Verify managed identity has "Key Vault Secrets User" role
2. **Secret Not Found**: Check secret naming convention and verify secret exists
3. **Empty Environment Variables**: Verify secret values are not empty in Key Vault
4. **Permission Issues**: Ensure Key Vault RBAC is enabled and properly configured

## Migration from Hardcoded Secrets

### Steps to Migrate

1. **Audit current secrets**: Identify all hardcoded secrets in configuration files
2. **Create Key Vault secrets**: Add secrets using the naming convention
3. **Update application code**: Replace hardcoded values with environment variables
4. **Test in development**: Verify secret injection works correctly
5. **Deploy to higher environments**: Roll out to staging and production
6. **Remove hardcoded secrets**: Clean up configuration files and repository

### Example Migration

Before:
```yaml
# application.yml
spring:
  datasource:
    username: hardcoded_user
    password: hardcoded_password
```

After:
```yaml
# application.yml
spring:
  datasource:
    username: ${JAVA_APP_DEV_DB_USERNAME}
    password: ${JAVA_APP_DEV_DB_PASSWORD}
```

## Benefits

### Security
- ✅ Centralized secret management
- ✅ No secrets in source code or configuration files
- ✅ Audit trail for secret access
- ✅ Automatic secret rotation capability

### Operations
- ✅ Environment-specific secret isolation
- ✅ Simplified secret deployment
- ✅ Reduced configuration drift
- ✅ Better compliance and governance

### Development
- ✅ Consistent secret access patterns
- ✅ Easier local development setup
- ✅ Reduced secret-related incidents
- ✅ Improved developer experience
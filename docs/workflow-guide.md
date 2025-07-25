# Workflow Usage Guide

## Referencing Shared Workflows

From any service branch, reference shared workflows:

```yaml
uses: ./.github/workflows/shared-deploy.yml@shared-github-actions
```

## Required Secrets

Each service branch needs these repository secrets:
- AZURE_CLIENT_ID
- AZURE_TENANT_ID  
- AZURE_SUBSCRIPTION_ID
- ACR_LOGIN_SERVER
- KEYVAULT_NAME

## Environment Configuration

Workflows support multiple environments:
- dev: Automatic on push to develop
- staging: Automatic on push to release/*
- production: Automatic on push to main

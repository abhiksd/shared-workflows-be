# Contributing to Shared Workflows

## Making Changes

1. Switch to shared workflows branch:
   ```bash
   git checkout shared-github-actions
   ```

2. Make your changes to workflows or actions

3. Test with a service branch:
   ```bash
   git checkout my-java-app
   gh workflow run deploy.yml -f environment=dev
   ```

4. Commit and push:
   ```bash
   git checkout shared-github-actions
   git add .
   git commit -m "feat: improve deployment workflow"
   git push origin shared-github-actions
   ```

## Best Practices

- Always test workflow changes with service branches
- Document breaking changes
- Maintain backward compatibility when possible
- Use semantic commit messages

## Workflow Structure

- Keep workflows generic and reusable
- Use inputs for service-specific configurations
- Include comprehensive error handling
- Add detailed logging for debugging

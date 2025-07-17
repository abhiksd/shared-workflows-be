# Testing & CI/CD Pipeline Setup

This document outlines the comprehensive testing strategy, CI/CD pipeline, security scanning, and quality assurance setup implemented in this project.

## 📋 Overview

Our CI/CD pipeline implements multiple layers of quality assurance to ensure code quality, security, and reliability. Pull requests can only be merged after all quality gates pass successfully.

## 🧪 Testing Strategy

### Test Structure

```
apps/java-app/src/test/
├── java/com/example/javaapp/
│   ├── JavaAppApplicationTests.java          # Application context tests
│   ├── controller/
│   │   └── AppControllerTest.java            # REST API unit tests
│   ├── service/
│   │   └── UserServiceTest.java              # Business logic unit tests
│   ├── integration/
│   │   └── UserIntegrationTest.java          # End-to-end integration tests
│   └── regression/
│       └── UserApiRegressionTest.java        # Regression test suite
└── resources/
    └── application-test.properties           # Test-specific configuration
```

### Test Categories

#### 1. Unit Tests
- **Location**: `*Test.java` files in service/controller packages
- **Purpose**: Test individual components in isolation
- **Coverage**: 80% minimum line coverage required
- **Mock**: External dependencies using Mockito
- **Run Command**: `mvn test -Punit-tests`

#### 2. Integration Tests
- **Location**: `integration/*IntegrationTest.java`
- **Purpose**: Test full application stack with database
- **Database**: H2 in-memory database
- **Run Command**: `mvn verify -Pintegration-tests`

#### 3. Regression Tests
- **Location**: `regression/*RegressionTest.java`
- **Purpose**: Ensure backward compatibility and prevent regressions
- **Triggers**: Automatically run on release branches
- **Run Command**: `mvn test -Pregression-tests`

## 🔧 Build Configuration

### Maven Profiles

- **unit-tests**: Runs only unit tests, excludes integration and regression
- **integration-tests**: Runs integration tests with database setup
- **regression-tests**: Runs regression test suite
- **sonar**: Configures SonarQube analysis with coverage reports

### Code Coverage

- **Tool**: JaCoCo Maven Plugin
- **Minimum**: 80% line coverage
- **Reports**: Generated in `target/site/jacoco/`
- **Exclusions**: Main application class and configuration classes

## 🚀 CI/CD Pipeline

### Pull Request Workflow (`.github/workflows/pr-checks.yml`)

The pipeline consists of 9 parallel and sequential jobs:

#### 1. Unit Tests ✅
- Runs Maven unit tests with coverage
- Generates JaCoCo coverage report
- Fails if coverage < 80%
- Comments coverage percentage on PR

#### 2. Integration Tests ✅
- Runs full-stack integration tests
- Uses H2 database service
- Validates end-to-end functionality

#### 3. Regression Tests ⚡
- Triggered for release branches only
- Ensures backward compatibility
- Validates API contract stability

#### 4. SonarQube Security & Quality Scan 🔍
- Static code analysis
- Security vulnerability detection
- Code quality metrics
- Technical debt assessment
- Integrated with PR decoration

#### 5. Checkmarx SAST Scan 🛡️
- Static Application Security Testing
- Detects security vulnerabilities
- Scans for OWASP Top 10 issues
- Focuses on high/medium severity issues

#### 6. Dependency Vulnerability Scan 📦
- OWASP Dependency Check
- Scans for known CVEs in dependencies
- Fails build on CVSS score ≥ 7
- Supports suppression of false positives

#### 7. Build & Package 📦
- Compiles application
- Creates deployment artifacts
- Validates production readiness

#### 8. Security Policy Validation 🔒
- Validates Helm security contexts
- Ensures resource limits are defined
- Checks security policy compliance

#### 9. Quality Gate 🎯
- Final validation of all checks
- Updates PR status
- Blocks merge if any check fails

## 🔒 Security Scanning

### SonarQube Configuration

```properties
# SonarQube Settings
sonar.host.url=https://sonarcloud.io
sonar.organization=your-org
sonar.projectKey=java-app
sonar.coverage.jacoco.xmlReportPaths=target/site/jacoco/jacoco.xml
sonar.exclusions=**/JavaAppApplication.java,**/config/**/*
```

### Checkmarx Configuration

- **Scan Type**: SAST (Static Application Security Testing)
- **Severity Filter**: High, Medium
- **Categories**: SQL Injection, XSS, Command Injection
- **Team**: `/CxServer/SP/Company/TeamName`

### OWASP Dependency Check

- **CVSS Threshold**: 7.0 (High severity)
- **Suppressions**: Configured in `owasp-suppressions.xml`
- **Report Format**: HTML and XML

## 🚧 Branch Protection Rules

### Main Branch Protection
- **Required Reviews**: 2 approving reviews
- **Required Status Checks**: All 8 pipeline jobs must pass
- **Admin Enforcement**: Enabled
- **Dismiss Stale Reviews**: Enabled
- **Require Code Owner Reviews**: Enabled

### Develop Branch Protection
- **Required Reviews**: 1 approving review
- **Required Status Checks**: All 8 pipeline jobs must pass
- **Admin Enforcement**: Disabled
- **Dismiss Stale Reviews**: Enabled

## 📊 Quality Metrics

### Code Coverage Targets
- **Minimum Line Coverage**: 80%
- **Branch Coverage**: Tracked but not enforced
- **Method Coverage**: Tracked but not enforced

### SonarQube Quality Gates
- **Reliability**: A rating required
- **Security**: A rating required
- **Maintainability**: A rating required
- **Coverage**: ≥ 80%
- **Duplicated Lines**: < 3%

## 🔧 Local Development

### Running Tests Locally

```bash
# Run all unit tests
mvn clean test -Punit-tests

# Run integration tests
mvn clean verify -Pintegration-tests

# Run regression tests
mvn clean test -Pregression-tests

# Run all tests with coverage
mvn clean verify jacoco:report

# Run SonarQube analysis (requires SONAR_TOKEN)
mvn clean verify sonar:sonar -Psonar
```

### IDE Configuration

#### IntelliJ IDEA
1. Enable annotation processing for Lombok
2. Set test runner to JUnit 5
3. Configure coverage runner to use JaCoCo
4. Install SonarLint plugin for real-time analysis

#### VS Code
1. Install Java Extension Pack
2. Install SonarLint extension
3. Configure test runner for JUnit 5

## 🚀 Deployment Pipeline

### Environment Promotion

```
feature/bug-branch → develop → staging → main → production
                     ↓         ↓        ↓        ↓
                  Unit Tests Integration Regression Full Suite
                  Coverage   Full Suite  Tests     + Security
                  SonarQube  Security    API       Scans
                            Scans       Validation
```

### Deployment Gates

- **Development**: Unit tests + basic security scans
- **Staging**: Full test suite + integration tests
- **Production**: All tests + regression tests + security validation

## 📋 Required Secrets

Configure these secrets in your GitHub repository:

```
SONAR_TOKEN                    # SonarCloud authentication token
CHECKMARX_URL                  # Checkmarx server URL
CHECKMARX_USERNAME            # Checkmarx username
CHECKMARX_PASSWORD            # Checkmarx password  
CHECKMARX_CLIENT_SECRET       # Checkmarx OAuth client secret
```

## 🛠️ Maintenance

### Test Maintenance
- Review and update regression tests quarterly
- Update security scan configurations with new rules
- Monitor coverage trends and adjust thresholds
- Update dependency suppressions as needed

### Pipeline Maintenance
- Update action versions in workflows
- Review and update security scan configurations
- Monitor pipeline performance and optimize as needed
- Update branch protection rules as team grows

## 📈 Monitoring & Reporting

### Available Reports
- **Code Coverage**: `target/site/jacoco/index.html`
- **Test Results**: `target/surefire-reports/`
- **Dependency Check**: `target/dependency-check-report.html`
- **SonarQube**: Available on SonarCloud dashboard
- **Checkmarx**: Available on Checkmarx dashboard

### CI/CD Metrics
- Pipeline success rate
- Average build time
- Test execution time trends
- Code coverage trends
- Security vulnerability trends

## 🆘 Troubleshooting

### Common Issues

#### Tests Failing Locally But Passing in CI
- Check Java version compatibility
- Verify test dependencies in pom.xml
- Check test resource files

#### Coverage Below Threshold
- Add more unit tests for uncovered code
- Review exclusions in JaCoCo configuration
- Consider integration test coverage

#### Security Scan False Positives
- Add suppressions to `owasp-suppressions.xml`
- Update Checkmarx filter rules
- Document rationale for suppressions

#### PR Merge Blocked
- Ensure all status checks pass
- Check branch protection rule configuration
- Verify required reviews are obtained

## 📚 Additional Resources

- [Spring Boot Testing Guide](https://spring.io/guides/gs/testing-web/)
- [JaCoCo Documentation](https://www.jacoco.org/jacoco/trunk/doc/)
- [SonarQube Java Analysis](https://docs.sonarqube.org/latest/analysis/languages/java/)
- [OWASP Dependency Check](https://owasp.org/www-project-dependency-check/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/defining-the-mergeability-of-pull-requests/about-protected-branches)

---

## ✅ Implementation Checklist

- [x] Unit test framework setup
- [x] Integration test configuration
- [x] Regression test suite
- [x] Code coverage with JaCoCo
- [x] SonarQube integration
- [x] Checkmarx SAST scanning
- [x] OWASP dependency checking
- [x] GitHub Actions CI/CD pipeline
- [x] Branch protection rules
- [x] Quality gate enforcement
- [x] PR merge protection
- [x] Security policy validation
- [x] Documentation and maintenance guides

**Status**: ✅ Complete - All testing and CI/CD components implemented and configured
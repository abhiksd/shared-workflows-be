# ⚓ Helm Integration Guide

Complete guide for Helm chart integration with Blue-Green deployment support for Java Backend1 microservice.

## 📋 **Table of Contents**

- [Overview](#overview)
- [Helm Chart Structure](#helm-chart-structure)
- [Chart Templates](#chart-templates)
- [Values Configuration](#values-configuration)
- [Blue-Green Deployment Support](#blue-green-deployment-support)
- [Environment-Specific Configurations](#environment-specific-configurations)
- [Helm Commands and Operations](#helm-commands-and-operations)
- [Testing and Validation](#testing-and-validation)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## 🎯 **Overview**

### **Helm Chart Features**
- ✅ **Multi-Environment Support**: dev, sqe, ppr, prod
- ✅ **Blue-Green Deployment**: Namespace-based slot management
- ✅ **ConfigMap Integration**: Environment-specific configurations
- ✅ **Secret Management**: Azure Key Vault integration
- ✅ **Health Checks**: Kubernetes liveness/readiness probes
- ✅ **Resource Management**: CPU/Memory limits and requests
- ✅ **Horizontal Pod Autoscaling**: Automatic scaling based on metrics
- ✅ **Ingress Configuration**: NGINX ingress with SSL termination
- ✅ **Service Mesh Ready**: Annotations for service mesh integration

## 📁 **Helm Chart Structure**

```
helm/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-dev.yaml              # Development environment values
├── values-sqe.yaml              # SQE environment values
├── values-ppr.yaml              # Pre-production environment values
├── values-prod.yaml             # Production environment values
├── templates/
│   ├── _helpers.tpl             # Helper templates
│   ├── configmap.yaml           # ConfigMap for application config
│   ├── secret.yaml              # Secret for sensitive data
│   ├── deployment.yaml          # Deployment manifest
│   ├── service.yaml             # Service manifest
│   ├── ingress.yaml             # Ingress manifest
│   ├── hpa.yaml                 # Horizontal Pod Autoscaler
│   ├── pdb.yaml                 # Pod Disruption Budget
│   ├── servicemonitor.yaml      # Prometheus ServiceMonitor
│   └── tests/
│       └── test-connection.yaml # Helm test for connectivity
├── charts/                      # Sub-chart dependencies
└── crds/                        # Custom Resource Definitions
```

### **Chart.yaml Configuration**
```yaml
# helm/Chart.yaml
apiVersion: v2
name: java-backend1
description: Java Backend1 microservice with Blue-Green deployment support
type: application
version: 1.0.0
appVersion: "1.0.0"
home: https://github.com/your-org/java-backend1
sources:
  - https://github.com/your-org/java-backend1
maintainers:
  - name: DevOps Team
    email: devops@yourcompany.com
keywords:
  - java
  - springboot
  - microservice
  - blue-green
  - kubernetes
annotations:
  category: Application
dependencies: []
```

## 📄 **Chart Templates**

### **Helper Templates (`_helpers.tpl`)**
```yaml
{{/*
helm/templates/_helpers.tpl
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "java-backend1.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "java-backend1.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "java-backend1.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "java-backend1.labels" -}}
helm.sh/chart: {{ include "java-backend1.chart" . }}
{{ include "java-backend1.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
deployment-slot: {{ .Values.global.deploymentSlot | default "blue" }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "java-backend1.selectorLabels" -}}
app.kubernetes.io/name: {{ include "java-backend1.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
deployment-slot: {{ .Values.global.deploymentSlot | default "blue" }}
{{- end }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "java-backend1.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "java-backend1.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create namespace name for Blue-Green deployment
*/}}
{{- define "java-backend1.namespace" -}}
{{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
{{- printf "%s-%s-%s" .Values.global.environment .Values.global.applicationName (.Values.global.deploymentSlot | default "blue") }}
{{- else }}
{{- .Release.Namespace }}
{{- end }}
{{- end }}

{{/*
Create ingress host based on environment
*/}}
{{- define "java-backend1.ingressHost" -}}
{{- if eq .Values.global.environment "dev" }}
{{- "dev.mydomain.com" }}
{{- else if eq .Values.global.environment "sqe" }}
{{- "sqe.mydomain.com" }}
{{- else if eq .Values.global.environment "ppr" }}
{{- "preprod.mydomain.com" }}
{{- else if eq .Values.global.environment "prod" }}
{{- "api.mydomain.com" }}
{{- else }}
{{- "localhost" }}
{{- end }}
{{- end }}
```

### **ConfigMap Template**
```yaml
# helm/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "java-backend1.fullname" . }}-config
  namespace: {{ include "java-backend1.namespace" . }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
data:
  application.yml: |
    spring:
      profiles:
        active: {{ .Values.global.environment }}
      application:
        name: {{ .Values.global.applicationName }}
      
      {{- if .Values.database.enabled }}
      datasource:
        url: {{ .Values.database.url | quote }}
        username: {{ .Values.database.username | quote }}
        driver-class-name: {{ .Values.database.driverClassName | quote }}
        hikari:
          maximum-pool-size: {{ .Values.database.hikari.maximumPoolSize }}
          minimum-idle: {{ .Values.database.hikari.minimumIdle }}
          connection-timeout: {{ .Values.database.hikari.connectionTimeout }}
          idle-timeout: {{ .Values.database.hikari.idleTimeout }}
          max-lifetime: {{ .Values.database.hikari.maxLifetime }}
      {{- end }}
      
      {{- if .Values.redis.enabled }}
      redis:
        url: {{ .Values.redis.url | quote }}
        timeout: {{ .Values.redis.timeout }}
        lettuce:
          pool:
            max-active: {{ .Values.redis.lettuce.pool.maxActive }}
            max-idle: {{ .Values.redis.lettuce.pool.maxIdle }}
            min-idle: {{ .Values.redis.lettuce.pool.minIdle }}
      {{- end }}
    
    server:
      port: {{ .Values.service.port }}
      servlet:
        context-path: /{{ .Values.global.applicationName }}
    
    management:
      endpoints:
        web:
          exposure:
            include: {{ .Values.management.endpoints.web.exposure.include | quote }}
          base-path: /actuator
      endpoint:
        health:
          show-details: {{ .Values.management.endpoint.health.showDetails }}
          probes:
            enabled: {{ .Values.management.endpoint.health.probes.enabled }}
    
    {{- if .Values.global.blueGreenEnabled }}
    deployment:
      slot: {{ .Values.global.deploymentSlot | default "blue" | quote }}
      environment: {{ .Values.global.environment | quote }}
    {{- end }}
    
    {{- with .Values.application }}
    app:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    {{- with .Values.features }}
    features:
      {{- toYaml . | nindent 6 }}
    {{- end }}
    
    logging:
      level:
        com.yourcompany.javabackend1: {{ .Values.logging.level.application }}
        root: {{ .Values.logging.level.root }}
```

### **Deployment Template**
```yaml
# helm/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "java-backend1.fullname" . }}
  namespace: {{ include "java-backend1.namespace" . }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
  annotations:
    deployment.kubernetes.io/revision: "{{ .Release.Revision }}"
    {{- with .Values.deployment.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "java-backend1.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "java-backend1.selectorLabels" . | nindent 8 }}
        version: {{ .Chart.AppVersion | quote }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "java-backend1.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
            - name: management
              containerPort: {{ .Values.service.managementPort | default 8080 }}
              protocol: TCP
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: {{ .Values.global.environment | quote }}
            - name: SPRING_CONFIG_LOCATION
              value: "classpath:/application.yml,/app/config/application.yml"
            {{- if .Values.global.blueGreenEnabled }}
            - name: DEPLOYMENT_SLOT
              value: {{ .Values.global.deploymentSlot | default "blue" | quote }}
            {{- end }}
            - name: KUBERNETES_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            {{- with .Values.env }}
            {{- range . }}
            - name: {{ .name }}
              {{- if .value }}
              value: {{ .value | quote }}
              {{- else if .valueFrom }}
              valueFrom:
                {{- toYaml .valueFrom | nindent 16 }}
              {{- end }}
            {{- end }}
            {{- end }}
          envFrom:
            - secretRef:
                name: {{ include "java-backend1.fullname" . }}-secret
          volumeMounts:
            - name: config-volume
              mountPath: /app/config
              readOnly: true
            {{- with .Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
          livenessProbe:
            httpGet:
              path: /{{ .Values.global.applicationName }}/actuator/health/liveness
              port: http
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.livenessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold }}
            successThreshold: {{ .Values.livenessProbe.successThreshold }}
          readinessProbe:
            httpGet:
              path: /{{ .Values.global.applicationName }}/actuator/health/readiness
              port: http
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.readinessProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold }}
            successThreshold: {{ .Values.readinessProbe.successThreshold }}
          startupProbe:
            httpGet:
              path: /{{ .Values.global.applicationName }}/actuator/health
              port: http
            initialDelaySeconds: {{ .Values.startupProbe.initialDelaySeconds }}
            periodSeconds: {{ .Values.startupProbe.periodSeconds }}
            timeoutSeconds: {{ .Values.startupProbe.timeoutSeconds }}
            failureThreshold: {{ .Values.startupProbe.failureThreshold }}
            successThreshold: {{ .Values.startupProbe.successThreshold }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
      volumes:
        - name: config-volume
          configMap:
            name: {{ include "java-backend1.fullname" . }}-config
        {{- with .Values.volumes }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
      restartPolicy: Always
```

### **Service Template**
```yaml
# helm/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "java-backend1.fullname" . }}
  namespace: {{ include "java-backend1.namespace" . }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
    {{- if .Values.service.managementPort }}
    - port: {{ .Values.service.managementPort }}
      targetPort: management
      protocol: TCP
      name: management
    {{- end }}
  selector:
    {{- include "java-backend1.selectorLabels" . | nindent 4 }}
  {{- if eq .Values.service.type "LoadBalancer" }}
  {{- with .Values.service.loadBalancerIP }}
  loadBalancerIP: {{ . }}
  {{- end }}
  {{- with .Values.service.loadBalancerSourceRanges }}
  loadBalancerSourceRanges:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- end }}
```

### **Ingress Template**
```yaml
# helm/templates/ingress.yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "java-backend1.fullname" . }}-ingress
  {{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
  namespace: default  # Main ingress in default namespace for Blue-Green
  {{- else }}
  namespace: {{ include "java-backend1.namespace" . }}
  {{- end }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
    {{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
    active-slot: {{ .Values.global.deploymentSlot | default "blue" }}
    {{- end }}
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /$2
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    # SSL termination handled by Azure Application Gateway
    {{- with .Values.ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  # SSL termination handled by Azure Application Gateway - no TLS config needed
  rules:
    - host: {{ include "java-backend1.ingressHost" . }}
      http:
        paths:
          - path: /({{ .Values.global.applicationName }}/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: {{ include "java-backend1.fullname" . }}
                {{- if and .Values.global.blueGreenEnabled (or (eq .Values.global.environment "ppr") (eq .Values.global.environment "prod")) }}
                namespace: {{ include "java-backend1.namespace" . }}
                {{- end }}
                port:
                  number: {{ .Values.service.port }}
{{- end }}
```

### **HPA Template**
```yaml
# helm/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "java-backend1.fullname" . }}
  namespace: {{ include "java-backend1.namespace" . }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "java-backend1.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
    {{- with .Values.autoscaling.customMetrics }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: {{ .Values.autoscaling.behavior.scaleDown.stabilizationWindowSeconds }}
      policies:
        - type: Percent
          value: {{ .Values.autoscaling.behavior.scaleDown.percentPolicy }}
          periodSeconds: {{ .Values.autoscaling.behavior.scaleDown.periodSeconds }}
    scaleUp:
      stabilizationWindowSeconds: {{ .Values.autoscaling.behavior.scaleUp.stabilizationWindowSeconds }}
      policies:
        - type: Percent
          value: {{ .Values.autoscaling.behavior.scaleUp.percentPolicy }}
          periodSeconds: {{ .Values.autoscaling.behavior.scaleUp.periodSeconds }}
{{- end }}
```

### **Secret Template**
```yaml
# helm/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "java-backend1.fullname" . }}-secret
  namespace: {{ include "java-backend1.namespace" . }}
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
type: Opaque
data:
  {{- range $key, $value := .Values.secrets }}
  {{ $key }}: {{ $value | b64enc | quote }}
  {{- end }}
```

## ⚙️ **Values Configuration**

### **Default Values (`values.yaml`)**
```yaml
# helm/values.yaml
# Global configuration
global:
  environment: local
  applicationName: java-backend1
  applicationType: java-springboot
  blueGreenEnabled: false
  deploymentSlot: blue

# Image configuration
image:
  repository: your-acr.azurecr.io/java-backend1
  pullPolicy: IfNotPresent
  tag: "latest"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

# Replica configuration
replicaCount: 1

# Service configuration
service:
  type: ClusterIP
  port: 8080
  managementPort: 8080
  annotations: {}

# Ingress configuration
ingress:
  enabled: true
  className: nginx
  annotations: {}
  # SSL termination handled by Azure Application Gateway

# Database configuration
database:
  enabled: false
  url: "jdbc:h2:mem:testdb"
  username: "sa"
  driverClassName: "org.h2.Driver"
  hikari:
    maximumPoolSize: 10
    minimumIdle: 2
    connectionTimeout: 30000
    idleTimeout: 600000
    maxLifetime: 1800000

# Redis configuration
redis:
  enabled: false
  url: "redis://localhost:6379"
  timeout: "2000ms"
  lettuce:
    pool:
      maxActive: 8
      maxIdle: 8
      minIdle: 0

# Application configuration
application:
  cors:
    allowedOrigins: "http://localhost:3000"
  jwt:
    expiration: 86400000  # 24 hours

# Feature flags
features:
  newUserRegistration: true
  emailNotifications: true
  advancedAnalytics: false

# Environment variables
env: []

# Secrets (will be base64 encoded)
secrets: {}

# Management endpoints
management:
  endpoints:
    web:
      exposure:
        include: "health,info,metrics,prometheus"
  endpoint:
    health:
      showDetails: "always"
      probes:
        enabled: true

# Logging configuration
logging:
  level:
    application: INFO
    root: INFO

# Probes configuration
livenessProbe:
  initialDelaySeconds: 60
  periodSeconds: 30
  timeoutSeconds: 5
  failureThreshold: 3
  successThreshold: 1

readinessProbe:
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
  successThreshold: 1

startupProbe:
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30
  successThreshold: 1

# Resource limits and requests
resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

# Autoscaling
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      percentPolicy: 10
      periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      percentPolicy: 50
      periodSeconds: 60

# Pod Disruption Budget
podDisruptionBudget:
  enabled: false
  minAvailable: 1

# Service Account
serviceAccount:
  create: true
  annotations: {}
  name: ""

# Pod Security Context
podSecurityContext:
  fsGroup: 1000
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000

# Container Security Context
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

# Pod annotations and labels
podAnnotations: {}
podLabels: {}

# Deployment annotations
deployment:
  annotations: {}

# Node selection
nodeSelector: {}
tolerations: []
affinity: {}

# Volumes and volume mounts
volumes: []
volumeMounts: []

# Termination grace period
terminationGracePeriodSeconds: 30

# Monitoring
monitoring:
  serviceMonitor:
    enabled: false
    interval: 30s
    path: /actuator/prometheus
    labels: {}
```

## 🔵🟢 **Blue-Green Deployment Support**

### **Blue-Green Values Override**
```yaml
# Blue-Green specific configuration that gets injected during deployment
blueGreen:
  enabled: true
  # Namespace pattern: {environment}-{applicationName}-{slot}
  # Examples: ppr-java-backend1-blue, prod-java-backend1-green
  
  # Traffic routing handled by ingress in default namespace
  ingress:
    mainNamespace: default
    slotAware: true
    
  # Service configuration for slot-specific services
  service:
    slotLabel: deployment-slot
    
  # Deployment configuration
  deployment:
    slotLabel: deployment-slot
    namespaceIsolation: true
```

### **Runtime Values Injection**
```bash
# Example of how runtime values are injected during Blue-Green deployment
helm upgrade --install java-backend1 ./helm \
  --namespace ppr-java-backend1-green \
  --create-namespace \
  --values ./helm/values-ppr.yaml \
  --set global.blueGreenEnabled=true \
  --set global.deploymentSlot=green \
  --set global.environment=ppr \
  --set image.tag=2024-01-15-12-00-abc123 \
  --wait --timeout=600s
```

## 🌍 **Environment-Specific Configurations**

### **Development Environment (`values-dev.yaml`)**
```yaml
# helm/values-dev.yaml
global:
  environment: dev
  blueGreenEnabled: false

replicaCount: 1

database:
  enabled: true
  url: "jdbc:postgresql://db-dev.postgres.database.azure.com:5432/java-backend1_dev"
  username: "java-backend1_user_dev"
  driverClassName: "org.postgresql.Driver"
  hikari:
    maximumPoolSize: 10
    minimumIdle: 2

redis:
  enabled: true
  url: "redis://redis-dev.redis.cache.windows.net:6380"

application:
  cors:
    allowedOrigins: "https://dev.mydomain.com"

features:
  newUserRegistration: true
  emailNotifications: true
  advancedAnalytics: false

logging:
  level:
    application: DEBUG
    root: INFO

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false

monitoring:
  serviceMonitor:
    enabled: true
```

### **Production Environment (`values-prod.yaml`)**
```yaml
# helm/values-prod.yaml
global:
  environment: prod
  blueGreenEnabled: true
  deploymentSlot: "{{ .Values.global.deploymentSlot | default \"blue\" }}"

replicaCount: 3

database:
  enabled: true
  url: "jdbc:postgresql://db-prod.postgres.database.azure.com:5432/java-backend1_prod"
  username: "java-backend1_user_prod"
  driverClassName: "org.postgresql.Driver"
  hikari:
    maximumPoolSize: 30
    minimumIdle: 10
    connectionTimeout: 20000
    leakDetectionThreshold: 60000

redis:
  enabled: true
  url: "redis://redis-prod.redis.cache.windows.net:6380"
  timeout: "1000ms"
  lettuce:
    pool:
      maxActive: 20
      maxIdle: 15
      minIdle: 5

application:
  cors:
    allowedOrigins: "https://api.mydomain.com"
  jwt:
    expiration: 3600000  # 1 hour

features:
  newUserRegistration: true
  emailNotifications: true
  advancedAnalytics: true

logging:
  level:
    application: WARN
    root: ERROR

resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 1000m
    memory: 1Gi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

podDisruptionBudget:
  enabled: true
  minAvailable: 2

nodeSelector:
  kubernetes.io/arch: amd64
  node-pool: production

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
    - weight: 100
      podAffinityTerm:
        labelSelector:
          matchExpressions:
          - key: app.kubernetes.io/name
            operator: In
            values:
            - java-backend1
        topologyKey: kubernetes.io/hostname

monitoring:
  serviceMonitor:
    enabled: true
    interval: 15s
```

## ⚓ **Helm Commands and Operations**

### **Installation Commands**
```bash
# Install to development environment
helm install java-backend1 ./helm \
  --namespace default \
  --values ./helm/values-dev.yaml \
  --set image.tag=latest \
  --create-namespace \
  --wait

# Install to production with Blue-Green (Blue slot)
helm install java-backend1 ./helm \
  --namespace prod-java-backend1-blue \
  --values ./helm/values-prod.yaml \
  --set global.deploymentSlot=blue \
  --set image.tag=v1.2.3 \
  --create-namespace \
  --wait --timeout=600s
```

### **Upgrade Commands**
```bash
# Upgrade development environment
helm upgrade java-backend1 ./helm \
  --namespace default \
  --values ./helm/values-dev.yaml \
  --set image.tag=v1.2.4 \
  --wait

# Blue-Green deployment to Green slot
helm upgrade --install java-backend1 ./helm \
  --namespace prod-java-backend1-green \
  --values ./helm/values-prod.yaml \
  --set global.deploymentSlot=green \
  --set image.tag=v1.2.4 \
  --create-namespace \
  --wait --timeout=600s
```

### **Rollback Commands**
```bash
# List release history
helm history java-backend1 --namespace default

# Rollback to previous version
helm rollback java-backend1 --namespace default

# Rollback to specific revision
helm rollback java-backend1 2 --namespace default
```

### **Management Commands**
```bash
# List releases
helm list --all-namespaces

# Get release status
helm status java-backend1 --namespace default

# Get release values
helm get values java-backend1 --namespace default

# Uninstall release
helm uninstall java-backend1 --namespace default
```

## 🧪 **Testing and Validation**

### **Helm Template Testing**
```bash
# Dry run with template rendering
helm template java-backend1 ./helm \
  --values ./helm/values-dev.yaml \
  --debug \
  --dry-run

# Validate templates without deploying
helm install java-backend1 ./helm \
  --values ./helm/values-dev.yaml \
  --dry-run --debug

# Lint chart for issues
helm lint ./helm

# Lint with specific values
helm lint ./helm --values ./helm/values-prod.yaml
```

### **Helm Test Configuration**
```yaml
# helm/templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "java-backend1.fullname" . }}-test-connection"
  labels:
    {{- include "java-backend1.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  restartPolicy: Never
  containers:
    - name: wget
      image: busybox:1.35
      command: ['wget']
      args: ['{{ include "java-backend1.fullname" . }}:{{ .Values.service.port }}/{{ .Values.global.applicationName }}/actuator/health']
  {{- with .Values.nodeSelector }}
  nodeSelector:
    {{- toYaml . | nindent 4 }}
  {{- end }}
```

### **Running Helm Tests**
```bash
# Run Helm tests
helm test java-backend1 --namespace default

# Run tests with logs
helm test java-backend1 --namespace default --logs

# Clean up test pods
kubectl delete pods -l "helm.sh/hook=test" --namespace default
```

## 🔧 **Troubleshooting**

### **Common Issues and Solutions**

#### **1. Template Rendering Issues**
```bash
# Debug template rendering
helm template java-backend1 ./helm \
  --values ./helm/values-dev.yaml \
  --debug \
  --set global.environment=dev

# Check specific template
helm template java-backend1 ./helm \
  --values ./helm/values-dev.yaml \
  --show-only templates/deployment.yaml
```

#### **2. Values Override Issues**
```bash
# Check final computed values
helm get values java-backend1 --namespace default --all

# Debug values precedence
helm template java-backend1 ./helm \
  --values ./helm/values.yaml \
  --values ./helm/values-dev.yaml \
  --set global.environment=debug \
  --debug
```

#### **3. Blue-Green Namespace Issues**
```bash
# Check if namespace exists
kubectl get namespace prod-java-backend1-blue

# Create namespace manually if needed
kubectl create namespace prod-java-backend1-blue

# Check namespace labels
kubectl get namespace prod-java-backend1-blue -o yaml
```

#### **4. Ingress Configuration Issues**
```bash
# Check ingress configuration
kubectl get ingress java-backend1-ingress -n default -o yaml

# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Test ingress connectivity
kubectl run test-pod --image=busybox --rm -it -- wget -qO- http://java-backend1:8080/backend1/actuator/health
```

### **Debugging Scripts**
```bash
#!/bin/bash
# debug-helm-deployment.sh

RELEASE_NAME=$1
NAMESPACE=$2

echo "🔍 Debugging Helm Release: ${RELEASE_NAME} in namespace: ${NAMESPACE}"

# Release information
echo "📋 Release Status:"
helm status ${RELEASE_NAME} --namespace ${NAMESPACE}

echo "📋 Release History:"
helm history ${RELEASE_NAME} --namespace ${NAMESPACE}

echo "📋 Release Values:"
helm get values ${RELEASE_NAME} --namespace ${NAMESPACE}

# Kubernetes resources
echo "📋 Deployment Status:"
kubectl get deployment -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}

echo "📋 Pod Status:"
kubectl get pods -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}

echo "📋 Service Status:"
kubectl get service -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}

echo "📋 Ingress Status:"
kubectl get ingress -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME}

# Recent events
echo "📋 Recent Events:"
kubectl get events -n ${NAMESPACE} --sort-by='.lastTimestamp' | tail -10

# Pod logs
echo "📋 Pod Logs (last 50 lines):"
kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE_NAME} --tail=50
```

## ✅ **Best Practices**

### **Chart Development Best Practices**
```yaml
1. Version Management:
   - Use semantic versioning for Chart.yaml
   - Tag images with specific versions
   - Maintain backward compatibility

2. Template Organization:
   - Use helper templates for reusable code
   - Keep templates readable and well-commented
   - Validate all user inputs

3. Values Design:
   - Provide sensible defaults
   - Document all values in comments
   - Use nested structures for organization

4. Security:
   - Use least privilege security contexts
   - Enable read-only root filesystem
   - Drop all capabilities by default
   - Use non-root users

5. Resource Management:
   - Set appropriate resource limits/requests
   - Configure HPA for scalability
   - Use PodDisruptionBudgets for availability

6. Monitoring:
   - Expose metrics endpoints
   - Configure proper health checks
   - Use structured logging
```

### **Blue-Green Deployment Best Practices**
```yaml
1. Namespace Strategy:
   - Use consistent naming patterns
   - Isolate slots in separate namespaces
   - Maintain ingress in default namespace

2. Traffic Management:
   - Test new slot before traffic switch
   - Implement health checks at ingress level
   - Monitor both slots during deployment

3. Cleanup Strategy:
   - Keep previous slot for rollback
   - Clean up old deployments after validation
   - Maintain deployment history

4. Database Considerations:
   - Ensure backward compatibility
   - Use database migrations carefully
   - Test rollback scenarios
```

### **Operational Best Practices**
```bash
# Chart testing pipeline
helm-test-pipeline() {
    local CHART_PATH=$1
    
    echo "🧪 Running Helm Chart Tests"
    
    # Lint chart
    helm lint ${CHART_PATH}
    
    # Template validation
    helm template test ${CHART_PATH} --debug --dry-run
    
    # Install and test
    helm install test-release ${CHART_PATH} --dry-run
    
    # Cleanup
    echo "✅ Chart tests completed"
}

# Blue-Green deployment verification
verify-blue-green-deployment() {
    local ENV=$1
    local SLOT=$2
    
    echo "🔍 Verifying Blue-Green deployment: ${ENV}-${SLOT}"
    
    # Check namespace
    kubectl get namespace ${ENV}-java-backend1-${SLOT}
    
    # Check deployment
    kubectl get deployment -n ${ENV}-java-backend1-${SLOT}
    
    # Check service
    kubectl get service -n ${ENV}-java-backend1-${SLOT}
    
    # Check ingress
    kubectl get ingress -n default java-backend1-ingress
    
    echo "✅ Blue-Green verification completed"
}
```

This comprehensive Helm integration guide provides everything needed to deploy and manage the Java Backend1 microservice with full Blue-Green deployment support!
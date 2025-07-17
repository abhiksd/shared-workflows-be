{{/*
Expand the name of the chart.
*/}}
{{- define "shared-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "shared-app.fullname" -}}
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
{{- define "shared-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "shared-app.labels" -}}
helm.sh/chart: {{ include "shared-app.chart" . }}
{{ include "shared-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ .Values.global.applicationName | default "shared-app" }}
{{- if .Values.global.environment }}
environment: {{ .Values.global.environment }}
{{- end }}
{{- if .Values.commonLabels }}
{{ toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "shared-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "shared-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "shared-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "shared-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified name for secrets.
*/}}
{{- define "shared-app.secretName" -}}
{{- if .Values.existingSecret }}
{{- .Values.existingSecret }}
{{- else }}
{{- printf "%s-secrets" (include "shared-app.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create a default fully qualified name for configmap.
*/}}
{{- define "shared-app.configMapName" -}}
{{- if .Values.existingConfigMap }}
{{- .Values.existingConfigMap }}
{{- else }}
{{- printf "%s-config" (include "shared-app.fullname" .) }}
{{- end }}
{{- end }}

{{/*
Create the database connection string
*/}}
{{- define "shared-app.databaseUrl" -}}
{{- if .Values.database.enabled }}
{{- if .Values.database.type | eq "postgresql" }}
{{- printf "postgresql://%s:%s@%s:%d/%s" .Values.database.username .Values.database.password .Values.database.host (.Values.database.port | default 5432) .Values.database.name }}
{{- else if .Values.database.type | eq "mysql" }}
{{- printf "mysql://%s:%s@%s:%d/%s" .Values.database.username .Values.database.password .Values.database.host (.Values.database.port | default 3306) .Values.database.name }}
{{- else }}
{{- printf "%s://%s:%s@%s:%d/%s" .Values.database.type .Values.database.username .Values.database.password .Values.database.host .Values.database.port .Values.database.name }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create Redis connection string
*/}}
{{- define "shared-app.redisUrl" -}}
{{- if .Values.redis.enabled }}
{{- if .Values.redis.password }}
{{- printf "redis://:%s@%s:%d" .Values.redis.password .Values.redis.host (.Values.redis.port | default 6379) }}
{{- else }}
{{- printf "redis://%s:%d" .Values.redis.host (.Values.redis.port | default 6379) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create ingress hostname
*/}}
{{- define "shared-app.ingressHost" -}}
{{- if .Values.ingress.hostname }}
{{- .Values.ingress.hostname }}
{{- else }}
{{- printf "%s-%s.%s" (include "shared-app.name" .) .Values.global.environment .Values.ingress.domain }}
{{- end }}
{{- end }}

{{/*
Create resource limits based on environment
*/}}
{{- define "shared-app.resources" -}}
{{- if eq .Values.global.environment "production" }}
limits:
  cpu: {{ .Values.resources.limits.cpu | default "1000m" }}
  memory: {{ .Values.resources.limits.memory | default "2Gi" }}
requests:
  cpu: {{ .Values.resources.requests.cpu | default "500m" }}
  memory: {{ .Values.resources.requests.memory | default "1Gi" }}
{{- else if eq .Values.global.environment "staging" }}
limits:
  cpu: {{ .Values.resources.limits.cpu | default "750m" }}
  memory: {{ .Values.resources.limits.memory | default "1.5Gi" }}
requests:
  cpu: {{ .Values.resources.requests.cpu | default "250m" }}
  memory: {{ .Values.resources.requests.memory | default "512Mi" }}
{{- else }}
limits:
  cpu: {{ .Values.resources.limits.cpu | default "500m" }}
  memory: {{ .Values.resources.limits.memory | default "1Gi" }}
requests:
  cpu: {{ .Values.resources.requests.cpu | default "100m" }}
  memory: {{ .Values.resources.requests.memory | default "256Mi" }}
{{- end }}
{{- end }}

{{/*
Create application port based on type
*/}}
{{- define "shared-app.applicationPort" -}}
{{- if eq .Values.global.applicationType "java-springboot" }}
{{- .Values.service.port | default 8080 }}
{{- else if eq .Values.global.applicationType "nodejs" }}
{{- .Values.service.port | default 3000 }}
{{- else }}
{{- .Values.service.port | default 8080 }}
{{- end }}
{{- end }}

{{/*
Create health check path based on application type
*/}}
{{- define "shared-app.healthPath" -}}
{{- if eq .Values.global.applicationType "java-springboot" }}
{{- .Values.healthPath | default "/actuator/health" }}
{{- else if eq .Values.global.applicationType "nodejs" }}
{{- .Values.healthPath | default "/health" }}
{{- else }}
{{- .Values.healthPath | default "/health" }}
{{- end }}
{{- end }}

{{/*
Create readiness check path based on application type
*/}}
{{- define "shared-app.readinessPath" -}}
{{- if eq .Values.global.applicationType "java-springboot" }}
{{- .Values.readinessPath | default "/actuator/health/readiness" }}
{{- else if eq .Values.global.applicationType "nodejs" }}
{{- .Values.readinessPath | default "/ready" }}
{{- else }}
{{- .Values.readinessPath | default "/ready" }}
{{- end }}
{{- end }}

{{/*
Create metrics path based on application type
*/}}
{{- define "shared-app.metricsPath" -}}
{{- if eq .Values.global.applicationType "java-springboot" }}
{{- .Values.metricsPath | default "/actuator/prometheus" }}
{{- else if eq .Values.global.applicationType "nodejs" }}
{{- .Values.metricsPath | default "/metrics" }}
{{- else }}
{{- .Values.metricsPath | default "/metrics" }}
{{- end }}
{{- end }}

{{/*
Validate required values
*/}}
{{- define "shared-app.validateValues" -}}
{{- if not .Values.global.environment }}
{{- fail "global.environment is required" }}
{{- end }}
{{- if not .Values.global.applicationName }}
{{- fail "global.applicationName is required" }}
{{- end }}
{{- if not .Values.image.repository }}
{{- fail "image.repository is required" }}
{{- end }}
{{- if and .Values.database.enabled (not .Values.database.host) }}
{{- fail "database.host is required when database is enabled" }}
{{- end }}
{{- if and .Values.redis.enabled (not .Values.redis.host) }}
{{- fail "redis.host is required when redis is enabled" }}
{{- end }}
{{- end }}

{{/*
Create PDB spec based on environment
*/}}
{{- define "shared-app.pdbSpec" -}}
{{- if eq .Values.global.environment "production" }}
{{- if .Values.podDisruptionBudget.minAvailable }}
minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
{{- else }}
minAvailable: {{ .Values.replicaCount | int | div 2 | add 1 }}
{{- end }}
{{- else }}
{{- if .Values.podDisruptionBudget.minAvailable }}
minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
{{- else }}
minAvailable: 1
{{- end }}
{{- end }}
{{- end }}

{{/*
Create affinity rules for high availability
*/}}
{{- define "shared-app.affinity" -}}
{{- if .Values.affinity }}
{{- toYaml .Values.affinity }}
{{- else }}
podAntiAffinity:
  {{- if eq .Values.global.environment "production" }}
  requiredDuringSchedulingIgnoredDuringExecution:
  - labelSelector:
      matchExpressions:
      - key: app.kubernetes.io/name
        operator: In
        values:
        - {{ include "shared-app.name" . }}
      - key: app.kubernetes.io/instance
        operator: In
        values:
        - {{ .Release.Name }}
    topologyKey: kubernetes.io/hostname
  {{- else }}
  preferredDuringSchedulingIgnoredDuringExecution:
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app.kubernetes.io/name
          operator: In
          values:
          - {{ include "shared-app.name" . }}
        - key: app.kubernetes.io/instance
          operator: In
          values:
          - {{ .Release.Name }}
      topologyKey: kubernetes.io/hostname
  {{- end }}
{{- end }}
{{- end }}

{{/*
Create image pull policy based on tag
*/}}
{{- define "shared-app.imagePullPolicy" -}}
{{- if .Values.image.pullPolicy }}
{{- .Values.image.pullPolicy }}
{{- else if contains "latest" (.Values.image.tag | default .Chart.AppVersion) }}
{{- "Always" }}
{{- else if eq .Values.global.environment "production" }}
{{- "IfNotPresent" }}
{{- else }}
{{- "Always" }}
{{- end }}
{{- end }}

{{/*
Create environment-specific replica count
*/}}
{{- define "shared-app.replicaCount" -}}
{{- if .Values.replicaCount }}
{{- .Values.replicaCount }}
{{- else if eq .Values.global.environment "production" }}
{{- 3 }}
{{- else if eq .Values.global.environment "staging" }}
{{- 2 }}
{{- else }}
{{- 1 }}
{{- end }}
{{- end }}

{{/*
Generate certificates for TLS
*/}}
{{- define "shared-app.gen-certs" -}}
{{- $altNames := list ( printf "%s.%s" (include "shared-app.name" .) .Release.Namespace ) ( printf "%s.%s.svc" (include "shared-app.name" .) .Release.Namespace ) -}}
{{- $ca := genCA "shared-app-ca" 365 -}}
{{- $cert := genSignedCert ( include "shared-app.name" . ) nil $altNames 365 $ca -}}
tls.crt: {{ $cert.Cert | b64enc }}
tls.key: {{ $cert.Key | b64enc }}
{{- end }}

{{/*
Common annotations for all resources
*/}}
{{- define "shared-app.commonAnnotations" -}}
{{- if .Values.commonAnnotations }}
{{- toYaml .Values.commonAnnotations }}
{{- end }}
meta.helm.sh/release-name: {{ .Release.Name }}
meta.helm.sh/release-namespace: {{ .Release.Namespace }}
{{- end }}
package main

import rego.v1

# Deny containers that run as root
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container '%s' should not run as root", [container.name])
}

# Deny containers without readOnlyRootFilesystem
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container '%s' should have readOnlyRootFilesystem enabled", [container.name])
}

# Deny containers that allow privilege escalation
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation == true
    msg := sprintf("Container '%s' should not allow privilege escalation", [container.name])
}

# Deny containers without resource limits
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%s' should have resource limits defined", [container.name])
}

# Deny containers without CPU limits
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container '%s' should have CPU limits defined", [container.name])
}

# Deny containers without memory limits
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container '%s' should have memory limits defined", [container.name])
}

# Deny pods without security context
deny contains msg if {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext
    msg := "Pod should have securityContext defined"
}

# Deny services without appropriate annotations
warn contains msg if {
    input.kind == "Service"
    not input.metadata.annotations["service.kubernetes.io/load-balancer-source-ranges"]
    msg := "Service should have load balancer source ranges defined for security"
}

# Deny ingress without TLS
deny contains msg if {
    input.kind == "Ingress"
    not input.spec.tls
    msg := "Ingress should have TLS configured"
}

# Check for proper network policies
warn contains msg if {
    input.kind == "NetworkPolicy"
    not input.spec.policyTypes
    msg := "NetworkPolicy should have policyTypes defined"
}

# Deny containers with privileged access
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container '%s' should not run in privileged mode", [container.name])
}

# Deny containers that add capabilities
deny contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    count(container.securityContext.capabilities.add) > 0
    msg := sprintf("Container '%s' should not add capabilities", [container.name])
}

# Deny containers that don't drop ALL capabilities
warn contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not "ALL" in container.securityContext.capabilities.drop
    msg := sprintf("Container '%s' should drop ALL capabilities", [container.name])
}

# Check for proper service account configuration
warn contains msg if {
    input.kind == "Deployment"
    not input.spec.template.spec.serviceAccountName
    msg := "Deployment should have a specific serviceAccountName defined"
}

# Deny automounting of service account tokens when not needed
deny contains msg if {
    input.kind == "Deployment"
    input.spec.template.spec.automountServiceAccountToken == true
    msg := "Deployment should not automount service account token unless required"
}

# Check for proper image pull policy
warn contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.imagePullPolicy != "Always"
    msg := sprintf("Container '%s' should have imagePullPolicy set to Always for security", [container.name])
}

# Deny containers without livenessProbe
warn contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container '%s' should have livenessProbe defined", [container.name])
}

# Deny containers without readinessProbe
warn contains msg if {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container '%s' should have readinessProbe defined", [container.name])
}
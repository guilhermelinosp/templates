# Controles de segurança para Pods/Deployments (Conftest / OPA).
# Cada regra gera uma violação com mensagem clara. Exceções para workloads de sistema
# devem ser documentadas aqui (ver 'exempt_namespaces' abaixo) e não por supressão genérica.
package kubernetes

import rego.v1

# Namespaces de sistema que podem precisar de privilégios; vazio por padrão.
exempt_namespaces := {}

# Prefixos de imagem confiáveis (dono no ghcr.io).
trusted_image_prefixes := ["ghcr.io/guilhermelinosp/"]

pod_spec := input.spec if input.kind == "Pod"
pod_spec := input.spec.template.spec if input.kind == "Deployment"
pod_spec := input.spec.template.spec if input.kind == "StatefulSet"
pod_spec := input.spec.template.spec if input.kind == "DaemonSet"

workload_ns := object.get(input.metadata, "namespace", "default")

containers contains c if {
	some c in pod_spec.containers
}

containers contains c if {
	some c in object.get(pod_spec, "initContainers", [])
}

applies if {
	pod_spec
	not workload_ns in exempt_namespaces
}

# --- host namespaces ---
deny contains msg if {
	applies
	pod_spec.hostNetwork == true
	msg := "hostNetwork não é permitido"
}

deny contains msg if {
	applies
	pod_spec.hostPID == true
	msg := "hostPID não é permitido"
}

deny contains msg if {
	applies
	pod_spec.hostIPC == true
	msg := "hostIPC não é permitido"
}

# --- privilégios por container ---
deny contains msg if {
	applies
	some c in containers
	c.securityContext.privileged == true
	msg := sprintf("container '%s' é privilegiado", [c.name])
}

deny contains msg if {
	applies
	some c in containers
	not c.securityContext
	msg := sprintf("container '%s' sem securityContext", [c.name])
}

deny contains msg if {
	applies
	some c in containers
	c.securityContext
	c.securityContext.allowPrivilegeEscalation == true
	msg := sprintf("container '%s' permite escalonamento de privilégio", [c.name])
}

deny contains msg if {
	applies
	some c in containers
	c.securityContext
	not c.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("container '%s' sem readOnlyRootFilesystem: true", [c.name])
}

# --- root ---
deny contains msg if {
	applies
	some c in containers
	not runs_as_non_root(c)
	msg := sprintf("container '%s' pode rodar como root (defina runAsNonRoot: true ou runAsUser > 0)", [c.name])
}

runs_as_non_root(c) if {
	c.securityContext.runAsNonRoot == true
}

runs_as_non_root(c) if {
	c.securityContext.runAsUser > 0
}

runs_as_non_root(c) if {
	not c.securityContext.runAsUser
	pod_spec.securityContext.runAsNonRoot == true
}

# --- capabilities ---
deny contains msg if {
	applies
	some c in containers
	some cap in object.get(object.get(c, "securityContext", {}), "capabilities", {"add": []}).add
	msg := sprintf("container '%s' adiciona capability '%s'", [c.name, cap])
}

# --- recursos ---
deny contains msg if {
	applies
	some c in containers
	not c.resources.requests.cpu
	msg := sprintf("container '%s' sem resources.requests.cpu", [c.name])
}

deny contains msg if {
	applies
	some c in containers
	not c.resources.requests.memory
	msg := sprintf("container '%s' sem resources.requests.memory", [c.name])
}

deny contains msg if {
	applies
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("container '%s' sem resources.limits.memory", [c.name])
}

# --- imagens ---
deny contains msg if {
	applies
	some c in containers
	not contains(c.image, "@sha256:")
	msg := sprintf("container '%s' usa tag mutável (%s); use digest @sha256:", [c.name, c.image])
}

deny contains msg if {
	applies
	some c in containers
	not trusted_registry(c.image)
	msg := sprintf("container '%s' usa registry não confiável (%s)", [c.name, c.image])
}

trusted_registry(image) if {
	some prefix in trusted_image_prefixes
	startswith(image, prefix)
}

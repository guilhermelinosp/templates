package kubernetes

import rego.v1

ok_image := "ghcr.io/guilhermelinosp/app@sha256:0000000000000000000000000000000000000000000000000000000000000000"

good_container := {
	"name": "app",
	"image": ok_image,
	"securityContext": {
		"allowPrivilegeEscalation": false,
		"readOnlyRootFilesystem": true,
		"runAsNonRoot": true,
		"capabilities": {"drop": ["ALL"]},
	},
	"resources": {"requests": {"cpu": "100m", "memory": "128Mi"}, "limits": {"memory": "256Mi"}},
}

pod(c) := {"kind": "Pod", "metadata": {"name": "t", "namespace": "app"}, "spec": {"containers": [c]}}

# caso valido: nenhuma violacao
test_valid_container_passes if {
	count(deny) == 0 with input as pod(good_container)
}

# privilegiado deve falhar
test_privileged_fails if {
	c := object.union(good_container, {"securityContext": object.union(good_container.securityContext, {"privileged": true})})
	deny["container 'app' é privilegiado"] with input as pod(c)
}

# tag mutavel deve falhar
test_mutable_tag_fails if {
	c := object.union(good_container, {"image": "ghcr.io/guilhermelinosp/app:latest"})
	some msg in deny with input as pod(c)
	contains(msg, "tag mutável")
}

# registry nao confiavel deve falhar
test_untrusted_registry_fails if {
	c := object.union(good_container, {"image": "docker.io/library/nginx@sha256:0000000000000000000000000000000000000000000000000000000000000000"})
	some msg in deny with input as pod(c)
	contains(msg, "registry não confiável")
}

# capability adicionada deve falhar
test_added_capability_fails if {
	c := object.union(good_container, {"securityContext": object.union(good_container.securityContext, {"capabilities": {"add": ["NET_ADMIN"]}})})
	some msg in deny with input as pod(c)
	contains(msg, "NET_ADMIN")
}

# sem limites de memoria deve falhar
test_missing_memory_limit_fails if {
	# object.union e recursivo: remove resources antes para o limite sumir de fato
	c := object.union(object.remove(good_container, ["resources"]), {"resources": {"requests": {"cpu": "100m", "memory": "128Mi"}}})
	some msg in deny with input as pod(c)
	contains(msg, "resources.limits.memory")
}

# hostNetwork no spec do pod deve falhar
test_host_network_fails if {
	p := object.union(pod(good_container), {"spec": object.union(pod(good_container).spec, {"hostNetwork": true})})
	deny["hostNetwork não é permitido"] with input as p
}

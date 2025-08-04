from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

config.load_kube_config()
v1 = client.AppsV1Api()

skipped_namespaces = [
    "kube-system",
    "cert-manager",
    "default",
    "monitoring",
    "tailscale",
    "cdi",
    "longhorn",
    "cattle-system",
    "cattle-fleet-system",
    "kubevirt",
    "cattle-fleet-local-system",
]
namespaces = [
    ns.metadata.name
    for ns in client.CoreV1Api().list_namespace().items
    if ns.metadata.name not in skipped_namespaces
]


# Define the annotations
annotations_to_add = {
    "keel.sh/policy": "all",
    "keel.sh/pollSchedule": "@every 1h",
    "keel.sh/trigger": "poll",
}

# Iterate over namespaces
for namespace_name in namespaces:
    deployments = v1.list_namespaced_deployment(namespace=namespace_name)

    # Iterate over deployments in the current namespace
    for dep in deployments.items:
        # Ensure the deployment has an annotations attribute, or create an
        # empty one
        if not dep.metadata.annotations:
            dep.metadata.annotations = {}

        # Add/overwrite the Keel annotations
        modified = False
        for key, value in annotations_to_add.items():
            if key in dep.metadata.annotations:
                continue
            dep.metadata.annotations[key] = value
            modified = True

        if not modified:
            print(
                f"Skipping deployment '{dep.metadata.name}' in the"
                + f"'{namespace_name}' namespace."
            )
            continue

        try:
            # Update the deployment with the new annotations
            v1.patch_namespaced_deployment(
                name=dep.metadata.name, namespace=namespace_name, body=dep
            )

            print(
                f"Added keel annotation to deployment '{dep.metadata.name}'"
                + f"in the '{namespace_name}' namespace."
            )
        except ApiException:
            print(
                f"Annotation for '{dep.metadata.name}'"
                + f"in the '{namespace_name}' namespace already added."
            )

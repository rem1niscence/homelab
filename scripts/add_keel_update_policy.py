from kubernetes import client, config

config.load_kube_config()
v1 = client.AppsV1Api()

print("starting script")
skipped_namespaces = ["kube-system",
                      "default",
                      "longhorn-system",
                      "cattle-system",
                      "cattle-fleet-system",
                      "cattle-fleet-local-system"]
namespaces = [ns.metadata.name for ns in client.CoreV1Api().list_namespace().items
              if ns.metadata.name not in skipped_namespaces]

# Define the annotations
annotations_to_add = {
    "keel.sh/policy": "all",
    "keel.sh/trigger": "poll",
    "keel.sh/pollSchedule": "@every 1h"
}

# Iterate over namespaces
for namespace_name in namespaces:
    deployments = v1.list_namespaced_deployment(namespace=namespace_name)

    # Iterate over deployments in the current namespace
    for dep in deployments.items:
        # Ensure the deployment has an annotations attribute, or create an empty one
        if not dep.metadata.annotations:
            dep.metadata.annotations = {}

        # Add/overwrite the Keel annotations
        for key, value in annotations_to_add.items():
            if key not in dep.metadata.annotations:
                dep.metadata.annotations[key] = value
                # Update the deployment with the new annotations
                v1.patch_namespaced_deployment(name=dep.metadata.name, namespace=namespace_name, body=dep)

                print(f"Added '{key}: {value}' annotation to all deployments in the '{namespace_name}' namespace.")

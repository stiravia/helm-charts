# kernavio-collector

The Kernavio collector runs in your Kubernetes cluster as a single pod. It reads the cluster's workloads and
configuration (read-only) and sends changes to Kernavio over outbound HTTPS. It accepts no inbound connections.

- Helm repository: `https://stiravia.github.io/helm-charts` (chart `stiravia/kernavio-collector`)
- OCI: `oci://ghcr.io/stiravia/charts/kernavio-collector`
- Image: `ghcr.io/stiravia/images/kernavio-collector`
- Chart files and releases: <https://github.com/stiravia/helm-charts/tree/main/charts/kernavio-collector>

## Requirements

- Kubernetes 1.25 or later
- Helm 3.8 or later
- Outbound HTTPS (port 443) from the cluster to `ingest.kernavio.com`
- An API key (`kv_col_...`) from the Kernavio console, created when you register the cluster

## Install

```sh
export KERNAVIO_API_KEY=kv_col_...        # from the Kernavio console

helm repo add stiravia https://stiravia.github.io/helm-charts
helm repo update

helm install kernavio-collector stiravia/kernavio-collector \
  --version <version> \
  --namespace kernavio --create-namespace \
  --set apiKey="$KERNAVIO_API_KEY"
```

Or install straight from the OCI registry, without adding the repository:

```sh
helm install kernavio-collector oci://ghcr.io/stiravia/charts/kernavio-collector \
  --version <version> \
  --namespace kernavio --create-namespace \
  --set apiKey="$KERNAVIO_API_KEY"
```

Both are the same chart. The commands below use the repository form, `stiravia/kernavio-collector`; with OCI, use
`oci://ghcr.io/stiravia/charts/kernavio-collector` in its place. Run `helm repo update` before an upgrade to see new
versions.

Check that it is running:

```sh
kubectl -n kernavio rollout status deployment/kernavio-collector
kubectl -n kernavio logs deployment/kernavio-collector
```

Within a few minutes the cluster shows as connected in the Kernavio console.

Passing the key through an environment variable keeps it out of your shell history. Helm also records the values
of each release in a Secret in the release namespace; to avoid that, use [your own Secret](#use-your-own-secret).

## Namespace and release name

The collector can run in any namespace: choose it with `--namespace`. Everything the chart creates in a namespace
(ServiceAccount, Secret, Role, Deployment) goes there, and the collector keeps its checkpoint ConfigMap
`kernavio-collector-state` in the same namespace. A dedicated namespace is recommended.

The examples in this guide use the namespace `kernavio` and the release name `kernavio-collector`. If you choose
others, replace them in every command, including the names derived from the release:

| Release name | Deployment and Secret are named |
|---|---|
| `kernavio-collector` (or any name containing it, e.g. `prod-kernavio-collector`) | the release name |
| anything else, e.g. `collector` | `<release>-kernavio-collector`, e.g. `collector-kernavio-collector` |

For example, with the namespace `observability` and the release `collector`:

```sh
helm install collector stiravia/kernavio-collector --version <version> \
  --namespace observability --create-namespace --set apiKey="$KERNAVIO_API_KEY"
kubectl -n observability logs deployment/collector-kernavio-collector
```

**Install one collector per cluster.** It needs a ClusterRole and ClusterRoleBinding, which are cluster-wide and
named after the release, and each cluster has its own API key. A second install of the chart in another namespace
fails with an "already exists" error if it uses the same release name, and with a different release name it would
run a second collector that conflicts with the first. To move the collector to another namespace, uninstall it
first, then install it in the new namespace (with `--set apiKey`, since the stored key stays behind in the old
namespace's Secret).

## Upgrade

The API key is stored in the Secret `kernavio-collector` on the first install, and every upgrade reads it from there.
You don't need to pass it again:

```sh
helm upgrade kernavio-collector stiravia/kernavio-collector \
  --version <version> --namespace kernavio
```

## Rotate the API key

Create a new key in the Kernavio console, then pass it once:

```sh
helm upgrade kernavio-collector stiravia/kernavio-collector \
  --version <version> --namespace kernavio --set apiKey="$NEW_KERNAVIO_API_KEY"
```

The collector restarts with the new key.

## Use your own Secret

Use this with Argo CD, External Secrets, Sealed Secrets or any tool that manages Secrets for you. Argo CD in
particular renders charts without access to the cluster, so it cannot read the stored key back; set
`existingSecret` there.

```sh
kubectl -n kernavio create secret generic kernavio-api-key --from-literal=api-key="$KERNAVIO_API_KEY"

helm install kernavio-collector stiravia/kernavio-collector \
  --version <version> --namespace kernavio --create-namespace \
  --set existingSecret=kernavio-api-key
```

If the key is stored under another name in the Secret, set `existingSecretKey` too. The chart creates no Secret of
its own in this mode.

## Uninstall

```sh
helm uninstall kernavio-collector --namespace kernavio
kubectl -n kernavio delete configmap kernavio-collector-state   # the collector's checkpoint
```

Then remove the cluster in the Kernavio console, which revokes its API key.

## Configuration

| Value | Default | Description |
|---|---|---|
| `apiKey` | `""` | API key from the Kernavio console. Required on the first install unless `existingSecret` is set |
| `existingSecret` | `""` | Name of a Secret you manage that holds the API key |
| `existingSecretKey` | `api-key` | Key in `existingSecret` that holds the API key |
| `endpoint` | `https://ingest.kernavio.com` | Where the collector sends data |
| `cluster.id` | `""` | Kernavio cluster ID, only written to the collector's logs |
| `configMapHosts` | `true` | Send hostnames found in ConfigMap values (never the values) for the dependency graph |
| `logLevel` | `info` | `debug`, `info`, `warn` or `error` |
| `image.repository` | `ghcr.io/stiravia/images/kernavio-collector` | Collector image |
| `image.tag` | chart `appVersion` | Image tag |
| `image.pullPolicy` | `IfNotPresent` | |
| `imagePullSecrets` | `[]` | For a private mirror of the image |
| `resources` | 100m CPU, 128Mi memory requested; 256Mi limit | |
| `nodeSelector`, `tolerations`, `affinity`, `priorityClassName` | empty | Pod scheduling |
| `podAnnotations`, `podLabels` | `{}` | Extra pod metadata |

See all values with:

```sh
helm show values stiravia/kernavio-collector --version <version>
```

## What the collector reads and sends

**Kubernetes access.** A ClusterRole grants `get`, `list` and `watch` (read-only) on Deployments, StatefulSets,
DaemonSets, ReplicaSets, CronJobs, Pods, Services, Ingresses, HTTPRoutes, ConfigMaps, Namespaces, Nodes and
HorizontalPodAutoscalers. **There is no access to Secrets.** A Role in the collector's own namespace allows it to
create and update one ConfigMap, `kernavio-collector-state`, where it keeps its position.

**What leaves the cluster:**

- Object metadata and specs of the kinds above, without `managedFields` and the last-applied annotation.
- ConfigMap values are replaced by `sha256:<hash>` before they are sent. Only the hostnames found in them are sent,
  for the dependency graph; set `configMapHosts=false` to turn that off.
- Container environment variables whose name contains `PASSWORD`, `TOKEN`, `SECRET` or `KEY` are sent as
  `[REDACTED]`, and `user:password@` is removed from URLs.
- Pods and Nodes are reduced to names, labels, images, scheduling, phase, readiness and restart counts.

**Pod security.** The collector runs as a non-root user (65532) with a read-only root filesystem, all Linux
capabilities dropped and the `RuntimeDefault` seccomp profile.

## Verify the chart before installing

Every release has a git tag `kernavio-collector-<version>` in <https://github.com/stiravia/helm-charts>, and a GitHub
Release with the packaged chart. To check that the chart you install is exactly the files at that tag:

```sh
helm pull stiravia/kernavio-collector --version <version> --untar -d /tmp/kernavio-chart

git clone --depth 1 --branch kernavio-collector-<version> https://github.com/stiravia/helm-charts.git
diff -r -x ci /tmp/kernavio-chart/kernavio-collector helm-charts/charts/kernavio-collector
```

`diff` printing nothing means the files are identical. To see the exact manifests the chart will apply:

```sh
helm template kernavio-collector stiravia/kernavio-collector \
  --version <version> --namespace kernavio --set apiKey=placeholder
```

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `apiKey is required on the first install` | Pass `--set apiKey=...` on the first install. On an upgrade it means the chart's Secret is gone, or the upgrade uses a different `--namespace` or release name than the install; use the same ones, or pass the key again |
| `... exists and cannot be imported into the current release` (ClusterRole) | A collector is already installed in this cluster, possibly in another namespace (`helm list -A`). Keep one collector per cluster |
| Logs show `401` | The API key is wrong or was revoked. Rotate it (see above) |
| Logs show `403 cluster_mismatch` | The key is already in use by another cluster. Each cluster needs its own key |
| `ImagePullBackOff` | The cluster cannot reach `ghcr.io`. Allow it, or mirror the image and set `image.repository` |
| Logs say a resource is forbidden or not served | That kind is skipped; the rest is collected. HTTPRoutes are skipped on clusters without the Gateway API |
| No connection to Kernavio | Check outbound HTTPS to `ingest.kernavio.com` (proxies, egress NetworkPolicies, firewalls) |

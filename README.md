# Stiravia Helm charts

Helm charts for installing Stiravia software in your Kubernetes cluster.

## Usage

[Helm](https://helm.sh) 3.8 or later must be installed. Add the repository:

```sh
helm repo add stiravia https://stiravia.github.io/helm-charts
helm repo update
helm search repo stiravia
```

Every chart is also published to the GitHub Container Registry, and can be installed from there without adding the
repository:

```sh
helm install <release> oci://ghcr.io/stiravia/charts/<chart> --version <version>
```

## Charts

| Chart | Description |
|---|---|
| [kernavio-collector](charts/kernavio-collector) | Watches a Kubernetes cluster and sends changes to Kernavio over outbound HTTPS |

Each chart's folder holds its current version and its usage guide (`README.md`). Every released version has a git
tag and a [GitHub Release](https://github.com/stiravia/helm-charts/releases) named `<chart>-<version>`, with the
packaged chart attached. To see the files of a specific version, browse the repository at that tag.

## Support

- Questions and bugs: [open an issue](https://github.com/stiravia/helm-charts/issues/new/choose).
- Security vulnerabilities: see [SECURITY.md](SECURITY.md); please do not open a public issue.

## License

Copyright © Stiravia. All rights reserved. See [LICENSE](LICENSE).

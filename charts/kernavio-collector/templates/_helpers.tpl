{{- define "collector.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "collector.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "collector.labels" -}}
{{ include "collector.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end -}}

{{- define "collector.secretName" -}}
{{- .Values.existingSecret | default (include "collector.fullname" .) -}}
{{- end -}}

{{- define "collector.secretKey" -}}
{{- if .Values.existingSecret -}}{{ .Values.existingSecretKey | default "api-key" }}{{- else -}}api-key{{- end -}}
{{- end -}}

{{/* The API key, base64-encoded: --set apiKey if given, otherwise the value an earlier install stored in the
Secret, so upgrades need no key. lookup sees nothing under helm template, --dry-run or Argo CD: use existingSecret
there. */}}
{{- define "collector.apiKeyB64" -}}
{{- if .Values.apiKey -}}
{{- .Values.apiKey | b64enc -}}
{{- else -}}
{{- $secret := lookup "v1" "Secret" .Release.Namespace (include "collector.fullname" .) -}}
{{- $stored := "" -}}
{{- if $secret -}}{{- $stored = index ($secret.data | default dict) "api-key" | default "" -}}{{- end -}}
{{- if $stored -}}
{{- $stored -}}
{{- else -}}
{{- fail "apiKey is required on the first install: --set apiKey=<key from the Kernavio console>, or set existingSecret" -}}
{{- end -}}
{{- end -}}
{{- end -}}

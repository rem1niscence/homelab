{{/*
app name
*/}}
{{- define "homepage.name" -}}
{{- .Release.Name | default "homepage" -}}
{{- end -}}

{{/*
common labels
*/}}
{{- define "homepage.labels" -}}
app.kubernetes.io/name: {{ include "homepage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
selector labels
*/}}
{{- define "homepage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homepage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

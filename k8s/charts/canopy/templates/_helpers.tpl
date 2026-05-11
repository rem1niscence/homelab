{{/*
Validator name — uses .Values.name or release name as fallback
*/}}
{{- define "validator.name" -}}
{{- .Values.name | default .Release.Name -}}
{{- end -}}

{{- define "validator.role" -}}
{{- .Values.role | default .Release.Name -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "validator.labels" -}}
app.kubernetes.io/name: {{ include "validator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: validator
canopynetwork.org/role: {{ include "validator.role" . }}
{{- if .Values.metrics.chain }}
canopynetwork.org/chain: {{ .Values.metrics.chain | quote }}
{{- end }}
{{- end -}}

{{/*
Selector labels
*/}}
{{- define "validator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "validator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: validator
{{- end -}}

{{/*
optional route prefix — renders as "prefix." or empty string
*/}}
{{- define "validator.hostPrefix" -}}
{{- if .Values.routes.validatorPrefix }}{{ .Values.routes.validatorPrefix }}-{{ end -}}
{{- end -}}

{{/*
Secret name for validator keys
*/}}
{{- define "validator.secretName" -}}
{{- printf "%s-key" (include "validator.name" .) -}}
{{- end -}}

FROM golang:1.24-alpine AS builder
ARG BINARY_PATH=backup
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o app ./cmd/${BINARY_PATH}

FROM alpine:3.22
RUN apk add --no-cache tar pigz ca-certificates
COPY --from=builder /app/app /usr/local/bin/app
CMD ["app"]

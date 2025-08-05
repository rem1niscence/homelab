FROM golang:1.24-alpine AS builder

WORKDIR /app

COPY ./src/go.mod ./src/go.sum ./

RUN go mod download

COPY ./src .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o backup-controller .

FROM alpine:latest

COPY --from=builder /app/backup-controller /usr/local/bin/backup-controller

CMD ["backup-controller"]

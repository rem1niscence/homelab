FROM alpine AS downloader
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache git

RUN apk add --no-cache libc6-compat git

RUN git clone https://github.com/umami-software/umami

FROM docker:latest
COPY --from=downloader /umami /build/
WORKDIR /build
RUN ls
RUN docker build -t your_image_name .
# WORKDIR /umami
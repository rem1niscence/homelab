# This docker image is basically the same one as the commit https://github.com/umami-software/umami/commit/ac8d8bbd1e6b28a4bb8a6eda67d5243339eacc47
# difference is that, in order to add a subpath to umami you need to pass the value as a build argument and,
# as I didn't want to download the repo here, this dockerfile downloads the repo as a stage, everything else remains unchanged

# Download Umami repository
FROM alpine/git AS downloader
WORKDIR /download
RUN git clone https://github.com/umami-software/umami .

# Install dependencies only when needed
FROM node:18-alpine AS deps
# Check https://github.com/nodejs/docker-node/tree/b4117f9333da4138b03a546ec926ef50a31506c3#nodealpine to understand why libc6-compat might be needed.
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY --from=downloader /download/package.json ./package.json
COPY --from=downloader /download/yarn.lock ./yarn.lock
RUN yarn install --frozen-lockfile

# Add yarn timeout to handle slow CPU when Github Actions
RUN yarn config set network-timeout 300000
RUN yarn install --frozen-lockfile

# Rebuild the source code only when needed
FROM node:18-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=downloader /download/docker/middleware.js .
COPY --from=downloader /download .

ARG DATABASE_TYPE
ARG BASE_PATH

ENV DATABASE_TYPE $DATABASE_TYPE
ENV BASE_PATH $BASE_PATH

ENV NEXT_TELEMETRY_DISABLED 1

RUN yarn build-docker

# Production image, copy all the files and run next
FROM node:18-alpine AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

RUN yarn add npm-run-all dotenv prisma

# You only need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder /app/next.config.js .
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/scripts ./scripts

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["yarn", "start-docker"]
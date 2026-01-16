# Multi-stage build for Next.js production runtime
# Based on node:24.12-alpine3.23 to match stack NODE_IMAGE

# Stage 1: Dependencies
FROM node:24.12-alpine3.23 AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package files
COPY package*.json ./
RUN npm ci --production=false

# Stage 2: Builder
FROM node:24.12-alpine3.23 AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Next.js production build
# This will fail gracefully if package.json is missing
RUN npm run build 2>/dev/null || echo "Build skipped: package.json missing or build script undefined"

# Stage 3: Runner
FROM node:24.12-alpine3.23 AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder /app/public ./public 2>/dev/null || true
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]

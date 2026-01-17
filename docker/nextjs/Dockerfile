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
RUN npm run build

# Ensure public directory exists (even if empty)
RUN mkdir -p /app/public

# Stage 3: Runner
FROM node:24.12-alpine3.23 AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copy built application
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public

USER nextjs

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]

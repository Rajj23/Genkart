FROM node:20-alpine AS base

# ── Install dependencies only when needed ────────────────────────────────────
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
RUN \
  if [ -f yarn.lock ]; then yarn --frozen-lockfile; \
  elif [ -f package-lock.json ]; then npm install; \
  elif [ -f pnpm-lock.yaml ]; then yarn global add pnpm && pnpm i --frozen-lockfile; \
  else echo "Lockfile not found." && exit 1; \
  fi

# ── Build the application ─────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Accept build-time env vars for Next.js NEXT_PUBLIC_ variables.
# These MUST be declared as ARGs and then set as ENVs before `npm run build`
# so that Next.js can bake them into the static bundle.
ARG NEXT_PUBLIC_API
ARG NEXT_PUBLIC_CLIENT_URL
ARG NEXT_PUBLIC_JWT_SECRET
ARG NEXT_PUBLIC_JWT_USER_SECRET
ARG NEXT_PUBLIC_NODE_ENV

ENV NEXT_PUBLIC_API=$NEXT_PUBLIC_API
ENV NEXT_PUBLIC_CLIENT_URL=$NEXT_PUBLIC_CLIENT_URL
ENV NEXT_PUBLIC_JWT_SECRET=$NEXT_PUBLIC_JWT_SECRET
ENV NEXT_PUBLIC_JWT_USER_SECRET=$NEXT_PUBLIC_JWT_USER_SECRET
ENV NEXT_PUBLIC_NODE_ENV=$NEXT_PUBLIC_NODE_ENV

ENV NEXT_TELEMETRY_DISABLED=1

RUN npm run build

# ── Production runner ─────────────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

RUN mkdir .next
RUN chown nextjs:nodejs .next

# Standalone output – copies only the files needed to run the server
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3005
ENV PORT=3005
ENV HOSTNAME="0.0.0.0"

# server.js is created by next build from the standalone output
CMD ["node", "server.js"]
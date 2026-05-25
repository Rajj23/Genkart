# Stage 1: Build dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: Copy source and add tini for proper signal handling
FROM node:20-alpine AS app
WORKDIR /app

# Install tini for signal handling
RUN apk add --no-cache tini

ENV NODE_ENV=production
ENV PORT=5560

# Copy only needed files
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Expose the port the app runs on
EXPOSE 5560

# Use tini as the entrypoint for proper signal handling
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["node", "index.js"]

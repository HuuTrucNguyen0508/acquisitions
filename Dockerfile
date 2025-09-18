# Multi-stage Dockerfile for Node.js application
FROM node:20-alpine AS base

# Install pnpm globally
RUN npm install -g pnpm@10.16.1

# Set working directory
WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml* ./

# Development stage
FROM base AS development
ENV NODE_ENV=development
RUN pnpm install --frozen-lockfile || pnpm install --force
COPY . .
EXPOSE 3000
CMD ["pnpm", "dev"]

# Production dependencies stage
FROM base AS deps
ENV NODE_ENV=production
RUN pnpm install --frozen-lockfile --prod || pnpm install --force --prod

# Production build stage
FROM node:20-alpine AS production

# Install pnpm
RUN npm install -g pnpm@10.16.1

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

WORKDIR /app

# Copy production dependencies
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=deps --chown=nodejs:nodejs /app/package.json ./package.json

# Copy application code
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })" || exit 1

# Start the application
CMD ["pnpm", "start"]
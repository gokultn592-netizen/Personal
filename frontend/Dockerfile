# Multi-stage production build for Next.js
FROM node:20-alpine AS builder
WORKDIR /app

ENV NEXT_TELEMETRY_DISABLED=1

COPY package*.json ./
RUN npm install --include=dev

COPY . .
RUN npm run build

# --- Runner stage ---
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

# 1. Copy public assets (including 3D models/textures)
COPY --from=builder /app/public ./public

# 2. Copy the entire .next build output
COPY --from=builder /app/.next ./.next

# 3. CRITICAL: Explicitly ensure .next/static is present for static asset routing
COPY --from=builder /app/.next/static ./.next/static

# 4. Copy runtime dependencies
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json

EXPOSE 3000
CMD ["npm", "start"]

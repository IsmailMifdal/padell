# --- Étape 1 : build (TypeScript → dist, client Prisma) ------------------
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY prisma ./prisma
RUN npx prisma generate

COPY tsconfig.json nest-cli.json ./
COPY src ./src
RUN npm run build \
    && npm prune --omit=dev

# --- Étape 2 : image d'exécution minimale --------------------------------
FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production

# OpenSSL requis par le moteur Prisma
RUN apk add --no-cache openssl

COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY package.json ./

EXPOSE 3000

# Applique les migrations puis démarre l'API
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main"]

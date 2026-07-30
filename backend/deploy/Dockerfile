FROM node:20-bookworm-slim AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY prisma ./prisma
COPY src ./src
COPY data ./data
RUN npx prisma generate && npm run build

FROM node:20-bookworm-slim

WORKDIR /app
ENV NODE_ENV=production

# Keep the Prisma CLI so schema changes can be applied explicitly with
# `docker compose run --rm api npx prisma db push --skip-generate`.
COPY package.json package-lock.json ./
RUN npm ci

COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/data ./data
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma

RUN useradd --system --uid 10001 appuser \
  && mkdir -p /app/uploads \
  && chown -R appuser:appuser /app
USER appuser

EXPOSE 3000
CMD ["node", "dist/index.js"]

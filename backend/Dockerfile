# ---- 构建阶段 ----
# 注意：用 debian 版 node，不能用 alpine——alpine 缺 openssl 会导致
# prisma generate 失败、产出无 model 类型的 stub client（tsc 编译报错）。
FROM node:20 AS build
WORKDIR /app
COPY package*.json ./
RUN npm config set registry https://registry.npmmirror.com
RUN npm ci
COPY prisma ./prisma
RUN npx prisma generate
COPY . .
RUN npm run build

# ---- 运行阶段 ----
FROM node:20 AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm config set registry https://registry.npmmirror.com
RUN npm ci --omit=dev
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/dist ./dist
COPY --from=build /app/prisma ./prisma
COPY --from=build /app/data ./data
EXPOSE 3000
CMD ["node","dist/index.js"]

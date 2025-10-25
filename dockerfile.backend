
FROM node:20-alpine AS builder

RUN apk update && apk add python3 make g++

WORKDIR /app

COPY package.json yarn.lock ./

RUN yarn install --production=false


COPY . .

WORKDIR /app/backend
RUN yarn build

FROM node:20-alpine AS runner

WORKDIR /app/backend

COPY package.json yarn.lock ./
RUN yarn install --production=true

COPY --from=builder /app/backend/dist ./dist
COPY --from=builder /app/backend/src ./src
COPY --from=builder /app/backend/medusa-config.js ./medusa-config.js
COPY --from=builder /app/backend/.env.template ./.env.template
COPY --from=builder /app/backend/package.json ./package.json

ENV PORT 9000
EXPOSE 9000

CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]

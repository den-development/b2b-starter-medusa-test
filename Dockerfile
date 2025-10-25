# Faz 1: Builder (Gerekli bağımlılıkları yükleme ve projeyi build etme)
FROM node:20-alpine AS builder

# Gerekli sistem paketlerini kurun
RUN apk update && apk add python3 make g++

# Konteyner içinde uygulama dizinini oluştur ve içine geç
WORKDIR /app

# SADECE REPO'DAKI "backend" KLASÖRÜNÜN İÇERİĞİNİ /app DİZİNİNE KOPYALA
# Bu, /app dizinini, repodaki /backend klasörünün içeriği (package.json, src, vb.) ile doldurur.
# Eğer Medusa projeniz root'taki "backend" klasöründe ise, bu kesindir.
COPY ./backend /app

# Corepack'i etkinleştirin ve projede tanımlı Yarn v4 sürümünü kullanın
RUN corepack enable && corepack prepare yarn@4.4.0 --activate

# Bağımlılıkları kur (WORKDIR /app olduğu için package.json'ı bulacak)
RUN yarn install --immutable

# Medusa backend'i build et
# Build komutları artık /app (backend projesinin kökü) içinde çalışacak
RUN yarn build


# Faz 2: Runner (Sadece production bağımlılıklarını ve build edilmiş kodu içerir)
FROM node:20-alpine AS runner

# Çalışma dizinini ana app klasörüne ayarlayın
WORKDIR /app

# 1. Gerekli dosyaları ve build output'unu kopyala
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/yarn.lock ./yarn.lock

# Eğer .yarnrc.yml varsa, bunu da kopyala (Hata vermemesi için || true ekliyoruz)
COPY --from=builder /app/.yarnrc.yml ./.yarnrc.yml || true

# Sadece üretim bağımlılıklarını kur
RUN yarn install --immutable --production

# 2. BUILD edilmiş kodu ve diğer gerekli dosyaları kopyala
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/src ./src
COPY --from=builder /app/medusa-config.js ./medusa-config.js
COPY --from=builder /app/.env.template ./.env.template
COPY --from=builder /app/data ./data

# Medusa'nın varsayılan olarak dinlediği port
ENV PORT 9000
EXPOSE 9000

# Başlangıç komutu
# Runner WORKDIR /app olduğu için, komut bu dizinden çalışacak.
CMD ["sh", "-c", "node_modules/.bin/medusa db:migrate && node_modules/.bin/medusa start"]

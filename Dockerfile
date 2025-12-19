# docker build -t mdzenos/portable_game:1.0 .
# docker push mdzenos/portable_game:1.0

# =======================
# 1. Build Spring Boot
# =======================
FROM maven:4.0.0-rc-5-eclipse-temurin-17 AS spring-build
WORKDIR /build

# Copy pom.xml và tải dependency offline
COPY be/pom.xml .
RUN mvn -B dependency:go-offline

# Copy source và build fat jar
COPY be/src ./src
RUN mvn -B package -DskipTests

# =======================
# 2. Runtime ALL-IN-ONE
# =======================
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV NODE_ENV=production
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC -Dfile.encoding=UTF-8"

# ---- base system ----
RUN apt-get update && apt-get install -y \
    nginx \
    supervisor \
    curl \
    ca-certificates \
    openjdk-17-jre-headless \
    && rm -rf /var/lib/apt/lists/*

# ---- node 22 + global tools ----
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs=22.* \
    && npm install -g npm@latest eslint typescript vite \
    && rm -rf /var/lib/apt/lists/*

# =======================
# 3. Frontend PixiJS Vite+TS + ESLint
# =======================
WORKDIR /fe
COPY fe/package.json fe/package-lock.json ./
RUN npm install --legacy-peer-deps

# Copy source, config Vite, ESLint và public
COPY fe/src ./src
COPY fe/vite.config.ts ./vite.config.ts
COPY fe/eslint.config.mjs ./eslint.config.mjs
COPY fe/public ./public

# Build FE (lint + tsc + vite build)
RUN npm run build

# Copy output dist vào Nginx
RUN cp -r dist/* /usr/share/nginx/html/

# =======================
# 4. Node SK (Socket.IO)
# =======================
WORKDIR /sk
COPY sk/package.json ./
RUN npm install --production
COPY sk/server.js ./

# =======================
# 5. Backend Spring Boot
# =======================
WORKDIR /backend
COPY --from=spring-build /build/target/*.jar app.jar

# =======================
# 6. Nginx
# =======================
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# =======================
# 7. Supervisor
# =======================
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# =======================
# 8. Ports
# =======================
EXPOSE 80 8081 8000

# =======================
# 9. CMD
# =======================
CMD ["/usr/bin/supervisord", "-n"]

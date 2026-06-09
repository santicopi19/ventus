# =============================================================================
# STAGE 1: Build grib2json (Java → JAR)
# =============================================================================
FROM maven:3-eclipse-temurin-11 AS builder

WORKDIR /tmp/grib2json

# Clone grib2json source
RUN git clone --depth 1 https://github.com/cambecc/grib2json.git .

# Patch pom.xml for Java 11 (the original targets Java 7)
RUN sed -i 's@<maven.compiler.source>[^<]*</maven.compiler.source>@<maven.compiler.source>11</maven.compiler.source>@; s@<maven.compiler.target>[^<]*</maven.compiler.target>@<maven.compiler.target>11</maven.compiler.target>@' pom.xml

# Build the JAR (skip tests to speed up)
RUN mvn package -DskipTests

# =============================================================================
# STAGE 2: Runtime — Node.js + Java (JRE only) + grib2json
# =============================================================================
FROM node:20-slim

# Install Java runtime (JRE) for grib2json, plus curl for downloading GFS data
RUN apt-get update && apt-get install -y --no-install-recommends \
    default-jre-headless \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy grib2json JAR and create wrapper script
COPY --from=builder /tmp/grib2json/target/grib2json-*.jar /opt/grib2json/grib2json.jar

RUN mkdir -p /opt/grib2json/bin && \
    echo '#!/bin/bash' > /opt/grib2json/bin/grib2json && \
    echo 'exec java -jar /opt/grib2json/grib2json.jar "$@"' >> /opt/grib2json/bin/grib2json && \
    chmod +x /opt/grib2json/bin/grib2json

# Set up environment
ENV GRIB2JSON_HOME=/opt/grib2json
ENV JAVA_HOME=/usr/lib/jvm/default-java

# Set up the app
WORKDIR /app

# Copy package.json first (for better layer caching)
COPY package.json package-lock.json* ./

RUN npm install --production

# Copy the rest of the app
COPY . .

EXPOSE 8080

# Start the server
CMD ["node", "server.js"]

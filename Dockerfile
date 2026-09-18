# ============================================================
# Experiment 6 — EchoRecorder Docker Image
# Multi-stage build: Flutter Web → Nginx Alpine
# ============================================================

# ----------------------------------------------------------
# Stage 1: Build the Flutter web application
# ----------------------------------------------------------
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy dependency manifests first for Docker layer caching
COPY pubspec.yaml pubspec.lock ./

# Pre-download dependencies
RUN flutter pub get

# Copy the rest of the application source
COPY lib/ lib/
COPY web/ web/
COPY assets/ assets/

# Build the Flutter web app (release mode)
RUN flutter build web --release

# ----------------------------------------------------------
# Stage 2: Serve with Nginx on Alpine (small, secure)
# ----------------------------------------------------------
FROM nginx:1.27-alpine

# Remove default Nginx static content
RUN rm -rf /usr/share/nginx/html/*

# Copy compiled Flutter web app from build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Run as non-root user (nginx user is built into the nginx image)
# Note: nginx master process needs root to bind port 80,
# but worker processes run as the 'nginx' user by default.

# Healthcheck
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost/ || exit 1

# Start Nginx in foreground
CMD ["nginx", "-g", "daemon off;"]

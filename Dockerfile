# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# Copy dependency files first to leverage Docker cache
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build the frontend application for the web
RUN flutter build web --release

# Stage 2: Serve the application with Nginx
FROM nginxinc/nginx-unprivileged:alpine

# Copy the custom Nginx configuration for single-page routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy the built Flutter web files from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port (Nginx default)
EXPOSE 8080

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]

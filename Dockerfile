# Stage 1: Build the Flutter Web application
FROM ghcr.io/cirruslabs/flutter@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build
WORKDIR /app

# Copy Flutter dependency manifests
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get --enforce-lockfile

# Copy Flutter source code and build for web
COPY . .
RUN flutter build web --release

# Stage 2: Serve Flutter Web + PHP & Python ML Backend via Apache
FROM php:8.2-apache

# Install Linux packages, PHP extensions, and Python ML dependencies (XGBoost, SHAP)
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip libzip-dev python3 python3-pip python3-dev build-essential \
    && pecl install redis \
    && docker-php-ext-install mysqli zip opcache \
    && docker-php-ext-enable mysqli zip opcache redis \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir --break-system-packages xgboost shap joblib pandas numpy scikit-learn

# Enable Apache rewrite module
RUN a2enmod rewrite

# Configure Apache to listen on port 8080 and port 80
RUN sed -i 's/Listen 80/Listen 80\nListen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:80 \*:8080>/' /etc/apache2/sites-available/000-default.conf

WORKDIR /var/www/html

# Copy built Flutter Web static assets to root web directory
COPY --from=build /app/build/web /var/www/html

# Copy PHP backend files to /var/www/html/api
COPY backend /var/www/html/api

# Install PHPMailer inside backend/vendor
WORKDIR /var/www/html/api
RUN php download_phpmailer.php

# Create SPA rewrite rules for Apache in /var/www/html/.htaccess
RUN echo '<IfModule mod_rewrite.c>\n\
    RewriteEngine On\n\
    RewriteBase /\n\
    RewriteCond %{REQUEST_FILENAME} -f [OR]\n\
    RewriteCond %{REQUEST_FILENAME} -d [OR]\n\
    RewriteCond %{REQUEST_URI} ^/api/\n\
    RewriteRule ^ - [L]\n\
    RewriteRule ^ index.html [L]\n\
</IfModule>' > /var/www/html/.htaccess

# Ensure Apache allow override for .htaccess
RUN sed -i 's/AllowOverride None/AllowOverride All/g' /etc/apache2/apache2.conf

# Set permissions for web server user
RUN chown -R www-data:www-data /var/www/html

WORKDIR /var/www/html

EXPOSE 8080
EXPOSE 80

CMD ["apache2-foreground"]


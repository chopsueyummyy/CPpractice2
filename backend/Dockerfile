# Use the official PHP Apache image
FROM php:8.2-apache

# Install dependencies for PHPMailer (unzip and zip extension) and OPcache
RUN apt-get update && apt-get install -y --no-install-recommends unzip libzip-dev \
    && docker-php-ext-install mysqli zip opcache \
    && docker-php-ext-enable mysqli zip opcache

# Copy OPcache configuration
COPY opcache.ini $PHP_INI_DIR/conf.d/opcache.ini

# Enable Apache mod_rewrite (common for PHP apps)
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Copy the PHP and image assets explicitly into the container
COPY *.php *.png opcache.ini /var/www/html/

# Run the downloader to install PHPMailer in the vendor folder
RUN php download_phpmailer.php

# Ensure permissions
RUN chown -R www-data:www-data /var/www/html

# Use unprivileged user www-data
USER www-data

# Expose port 80
EXPOSE 80

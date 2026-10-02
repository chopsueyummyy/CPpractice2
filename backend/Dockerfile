# Use the official PHP Apache image
FROM php:8.2-apache

# Install dependencies for PHPMailer, OPcache, Redis extension, and Python ML runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip libzip-dev python3 python3-pip python3-dev build-essential \
    && pecl install redis \
    && docker-php-ext-install mysqli zip opcache \
    && docker-php-ext-enable mysqli zip opcache redis \
    && rm -rf /var/lib/apt/lists/*

# Install Python ML dependencies for XGBoost & SHAP recommendation engine
RUN pip3 install --no-cache-dir --break-system-packages xgboost shap joblib pandas numpy scikit-learn

# Copy OPcache configuration
COPY opcache.ini $PHP_INI_DIR/conf.d/opcache.ini

# Enable Apache mod_rewrite (common for PHP apps)
RUN a2enmod rewrite

# Set working directory
WORKDIR /var/www/html

# Copy the PHP files into the container
COPY . /var/www/html/

# Run the downloader to install PHPMailer in the vendor folder
RUN php download_phpmailer.php

# Ensure permissions
RUN chown -R www-data:www-data /var/www/html

# Expose port 80
EXPOSE 80

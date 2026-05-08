# Use the version PHP 8.2 Alpine (light e safer)
FROM php:8.4-fpm-alpine

# Arguments for creating a non-root user (DevSecOps)
ARG UID=1000
ARG GID=1000

# Defines the working directory
WORKDIR /var/www/html

# Installs the PHP system dependencies and extensions for PostgreSQL, ZIP, and Java (for potential use in the application)
RUN apk add --no-cache \
    postgresql-dev \
    libzip-dev \
    zip \
    unzip \
    openjdk17-jre \
    bash \
    && docker-php-ext-install pdo pdo_pgsql zip

# Installs Composer (PHP package manager)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Creates a non-root user to run the application
RUN addgroup -g ${GID} laravel \
    && adduser -G laravel -u ${UID} -h /home/laravel -s /bin/sh -D laravel

# Adjusts folder permissions
RUN chown -R laravel:laravel /var/www/html

# Switches to the non-root user
USER laravel

# Exposes the PHP-FPM port
EXPOSE 9000

# Default command
CMD ["php-fpm"]

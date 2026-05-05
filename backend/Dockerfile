# Usa a versão Alpine do PHP 8.2 (mais leve e segura)
FROM php:8.2-fpm-alpine

# Argumentos para criar usuário não-root (DevSecOps)
ARG UID=1000
ARG GID=1000

# Define o diretório de trabalho
WORKDIR /var/www/html

# Instala as dependências do sistema e extensões do PHP para o PostgreSQL
RUN apk add --no-cache \
    postgresql-dev \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install pdo pdo_pgsql zip

# Instala o Composer (Gerenciador de pacotes do PHP)
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Cria um usuário sem privilégios de root para rodar a aplicação
RUN addgroup -g ${GID} laravel \
    && adduser -G laravel -u ${UID} -h /home/laravel -s /bin/sh -D laravel

# Ajusta permissões da pasta
RUN chown -R laravel:laravel /var/www/html

# Troca para o usuário seguro
USER laravel

# Expõe a porta do PHP-FPM
EXPOSE 9000

# Comando padrão
CMD ["php-fpm"]
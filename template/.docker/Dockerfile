FROM php:8.4-apache-trixie

ENV TZ=Europe/Prague \
    LANG=cs_CZ.UTF-8 \
    LC_ALL=cs_CZ.UTF-8 \
    # Allow runing composer as a superuser, since there is no other inside of the container.
    # See https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
    COMPOSER_ALLOW_SUPERUSER=1

# Updates and installs system dependencies
RUN set -eux; \
    apt update; \
    apt install -y --no-install-recommends \
    bash \
    curl \
    vim \
    tzdata \
    locales \
    imagemagick; \
    # Install Czech locale
    echo "cs_CZ.UTF-8 UTF-8" >> /etc/locale.gen; \
    locale-gen cs_CZ.UTF-8; \
    update-locale LANG=cs_CZ.UTF-8 LC_ALL=cs_CZ.UTF-8; \
    # Clean-up
    apt-get clean -y

# Configure ImageMagick to allow PDF read/write
RUN a2enmod rewrite \
    && a2enmod headers
    #&& sed -i 's#<policy domain="coder" rights="none" pattern="PDF" />#<policy domain="coder" rights="read | write" pattern="PDF" />#g' /etc/ImageMagick-6/policy.xml


# Install php dependencies
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN set -eux; \
    install-php-extensions \
    @composer \
    dom \
    soap \
    zip \
    gd \
    sockets \
    mysqli \
    mbstring \
    bcmath \
    apcu

# Copy config files
COPY .docker/php.ini ${PHP_INI_DIR}/conf.d/99-php.ini
COPY .docker/000-default.conf /etc/apache2/sites-available/000-default.conf

WORKDIR /app
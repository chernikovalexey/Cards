FROM google/dart:1.24 as buildenv

COPY web/ app/
COPY pubspec.yaml pubspec.yaml

RUN pub get
RUN dart2js app/cards.dart -o app/cards.dart.js
CMD tail -f /dev/null

FROM php:5.6-apache
RUN docker-php-ext-install pdo pdo_mysql mysqli
RUN a2enmod rewrite
COPY --from=buildenv /app/cards.dart.js /var/www/html/web
COPY / /var/www/html/
EXPOSE 80
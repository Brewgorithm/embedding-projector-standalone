FROM trinitronx/python-simplehttpserver:travis-12
EXPOSE 8080
WORKDIR /var/www
COPY . .

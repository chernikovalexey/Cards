FROM mysql:5.7
ENV MYSQL_DATABASE=twocubes
#COPY twocubes_shema.sql schema.sql
ADD twocubes_shema.sql /docker-entrypoint-initdb.d
#CMD mysql -u root -p PP4ScMGr3zbFQkHL < schema.sql

EXPOSE 3306

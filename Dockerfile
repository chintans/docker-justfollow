FROM ubuntu:trusty
RUN apt-get -y install curl wget
RUN curl -sL https://deb.nodesource.com/setup | sudo bash -
ADD redis/dotdeb.org.list /etc/apt/sources.list.d/dotdeb.org.list
RUN wget -q -O - http://www.dotdeb.org/dotdeb.gpg | sudo apt-key add -
# Add the PostgreSQL PGP key to verify their Debian packages.
# It should be the same key as https://www.postgresql.org/media/keys/ACCC4CF8.asc
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8
# Add PostgreSQL's repository. It contains the most recent stable release
#     of PostgreSQL, ``9.4``.
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update \
 && apt-get install -y git-core build-essential openssl libssl-dev pkg-config perl libssl1.0.0 libxslt1.1 libgd3 libxpm4 libgeoip1 libav-tools python python-dev python-pip python-virtualenv supervisor sqlite3  libsqlite3-dev gcc g++ make libc6-dev libpcre++-dev libssl-dev libxslt-dev libgd2-xpm-dev libgeoip-dev wget curl software-properties-common python-software-properties nodejs redis-server postgresql-9.4 postgresql-client-9.4 postgresql-contrib-9.4\
 && rm -rf /var/lib/apt/lists/* # 20150220
 
RUN easy_install pip
RUN pip install uwsgi
RUN sudo add-apt-repository ppa:nginx/development && sudo apt-get update && sudo apt-get install nginx-full -y
ADD nginx/apps.justfollow.it /etc/nginx/sites-available/apps.justfollow.it
ADD nginx/nginx.conf /etc/nginx/nginx.conf
RUN mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled && ln -s /etc/nginx/sites-available/apps.justfollow.it
RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle

# Run the rest of the commands as the ``postgres`` user created by the ``postgres-9.3`` package when it was ``apt-get installed``
USER postgres

# Create a PostgreSQL role named ``docker`` with ``docker`` as the password and
# then create a database `docker` owned by the ``docker`` role.
# Note: here we use ``&&\`` to run commands one after the other - the ``\``
#       allows the RUN command to span multiple lines.
RUN    /etc/init.d/postgresql start &&\
    psql --command "CREATE USER docker WITH SUPERUSER PASSWORD 'docker';" &&\
    createdb -O docker docker

# Adjust PostgreSQL configuration so that remote connections to the
# database are possible.
RUN echo "host all  all    0.0.0.0/0  md5" >> /etc/postgresql/9.4/main/pg_hba.conf

# And add ``listen_addresses`` to ``/etc/postgresql/9.4/main/postgresql.conf``
RUN echo "listen_addresses='*'" >> /etc/postgresql/9.4/main/postgresql.conf

# Expose the PostgreSQL port
EXPOSE 5432
EXPOSE 80
EXPOSE 443
EXPOSE 1935
EXPOSE 6379

VOLUME ["/var/cache/ngx_pagespeed","/data","/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

CMD ["supervisord"]

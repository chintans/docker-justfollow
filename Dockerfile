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

# download nginx-rtmp-module
#RUN mkdir -p /tmp/nginx-rtmp-module
#RUN curl -L https://github.com/arut/nginx-rtmp-module/archive/v1.1.5.tar.gz | tar -zxf - --strip=1 -C /tmp/nginx-rtmp-module

# download ngx_pagespeed
RUN mkdir -p /tmp/ngx_pagespeed
RUN curl -L https://github.com/pagespeed/ngx_pagespeed/archive/release-1.9.32.3-beta.tar.gz | tar -zxf - --strip=1 -C /tmp/ngx_pagespeed
RUN curl -L https://dl.google.com/dl/page-speed/psol/1.9.32.3.tar.gz | tar -zxf - -C /tmp/ngx_pagespeed

# compile nginx with the nginx-rtmp-module
RUN mkdir -p /tmp/nginx /usr/share/nginx/html /var/log/nginx
RUN curl -L http://nginx.org/download/nginx-1.7.10.tar.gz | tar -zxf - -C /tmp/nginx --strip=1

# use maximum available processor cores for the build
RUN alias make="make -j$(awk '/^processor/ { N++} END { print N }' /proc/cpuinfo)"

RUN cd /tmp/nginx &&./configure --prefix=/usr/share/nginx --conf-path=/etc/nginx/nginx.conf --sbin-path=/usr/sbin \
  --http-log-path=/var/log/nginx/access.log --error-log-path=/var/log/nginx/error.log \
  --lock-path=/var/lock/nginx.lock --pid-path=/run/nginx.pid \
  --http-client-body-temp-path=/var/lib/nginx/body \
  --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
  --http-proxy-temp-path=/var/lib/nginx/proxy \
  --http-scgi-temp-path=/var/lib/nginx/scgi \
  --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
  --with-pcre-jit --with-ipv6 --with-http_ssl_module \
  --with-http_stub_status_module --with-http_realip_module \
  --with-http_addition_module --with-http_dav_module --with-http_geoip_module \
  --with-http_gzip_static_module --with-http_image_filter_module \
  --with-http_spdy_module --with-http_sub_module --with-http_xslt_module \
  --with-mail --with-mail_ssl_module \  
  --add-module=/tmp/ngx_pagespeed && make -s && make -s install

ADD nginx/start /start
RUN chmod 755 /start

ADD nginx/nginx.conf /etc/nginx/nginx.conf

RUN echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | sudo /usr/bin/debconf-set-selections && \
  add-apt-repository -y ppa:webupd8team/java && \
  apt-get update && \
  apt-get install -y oracle-java8-installer && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /var/cache/oracle-jdk8-installer

# Define commonly used JAVA_HOME variable
ENV JAVA_HOME /usr/lib/jvm/java-8-oracle



# Install ``python-software-properties``, ``software-properties-common`` and PostgreSQL 9.3
#  There are some warnings (in red) that show up during the build. You can hide
#  them by prefixing each apt-get statement with DEBIAN_FRONTEND=noninteractive


# Note: The official Debian and Ubuntu images automatically ``apt-get clean``
# after each ``apt-get``

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

RUN easy_install pip
RUN pip install uwsgi

# Expose the PostgreSQL port
EXPOSE 5432
EXPOSE 80
EXPOSE 443
EXPOSE 1935
EXPOSE 6379

VOLUME ["/var/cache/ngx_pagespeed","/data","/etc/postgresql", "/var/log/postgresql", "/var/lib/postgresql"]

CMD ["/start","bash","redis-server","/etc/redis/redis.conf","/usr/lib/postgresql/9.4/bin/postgres", "-D", "/var/lib/postgresql/9.4/main", "-c", "config_file=/etc/postgresql/9.4/main/postgresql.conf","supervisord"]

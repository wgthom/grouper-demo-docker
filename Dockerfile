FROM ubuntu:trusty

MAINTAINER John Gasper <jgasper@unicon.net>

ENV JAVA_HOME=/opt/jdk1.7.0_79 \
    ANT_HOME=/opt/apache-ant-1.9.5 \
    PATH=$PATH:$JRE_HOME/bin:/opt/container-scripts:$ANT_HOME/bin \
    GROUPER_VERSION=2.3.0

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y slapd wget tar unzip dos2unix expect vim

RUN java_version=7u79; \    
    echo 'Downloading the JDK...' \    
    && wget -q --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" \
    http://download.oracle.com/otn-pub/java/jdk/$java_version-b15/jdk-$java_version-linux-x64.tar.gz \
    && echo 'Downloading Tomcat...'\
    && wget -q https://archive.apache.org/dist/tomcat/tomcat-6/v6.0.44/bin/apache-tomcat-6.0.44.zip \
    && echo 'Downloading Ant...'\
    && wget -q https://archive.apache.org/dist/ant/binaries/apache-ant-1.9.5-bin.zip \
    && echo 'Downloading grouper installer...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouperInstaller.jar \
    && echo 'Downloading grouper API...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouper.apiBinary-$GROUPER_VERSION.tar.gz \
    && echo 'Downloading grouper UI...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouper.ui-$GROUPER_VERSION.tar.gz \
    && echo 'Downloading grouper Web Services...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouper.ws-$GROUPER_VERSION.tar.gz \
    && echo 'Downloading grouper client...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouper.clientBinary-$GROUPER_VERSION.tar.gz \
    && echo 'Downloading grouper PSP...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/grouper.psp-$GROUPER_VERSION.tar.gz \
    && echo 'Downloading grouper Quickstart...'\
    && wget -q http://software.internet2.edu/grouper/release/$GROUPER_VERSION/quickstart.xml \
    \
    && echo "9222e097e624800fdd9bfb568169ccad  jdk-$java_version-linux-x64.tar.gz" | md5sum -c - \
    && tar -zxvf jdk-$java_version-linux-x64.tar.gz -C /opt 1>/dev/null \
    && rm jdk-$java_version-linux-x64.tar.gz \ 
    \
    && echo "409e93f383ec476cde4c9b87f2427dbf  apache-tomcat-6.0.44.zip" | md5sum -c - \
    && unzip apache-tomcat-6.0.44.zip -d /opt 1>/dev/null \    
    && rm apache-tomcat-6.0.44.zip \
    \
    && unzip apache-ant-1.9.5-bin.zip -d /opt 1>/dev/null \
    && echo "8c4193db6ac91c3f792a04715f8e9a82ef628daf  apache-ant-1.9.5-bin.zip" | sha1sum -c - \
    && rm apache-ant-1.9.5-bin.zip \
    && chmod +x /opt/apache-ant-1.9.5/bin/ant \
    \
    && tar -zxf grouper.apiBinary-$GROUPER_VERSION.tar.gz -C /opt \
    && tar -zxf grouper.ui-$GROUPER_VERSION.tar.gz -C /opt \
    && tar -zxf grouper.ws-$GROUPER_VERSION.tar.gz -C /opt \
    && tar -zxf grouper.clientBinary-$GROUPER_VERSION.tar.gz -C /opt \
    && tar -zxf grouper.psp-$GROUPER_VERSION.tar.gz -C /opt \
    &&  cp -R /opt/grouper.psp-$GROUPER_VERSION/lib/custom/* /opt/grouper.apiBinary-$GROUPER_VERSION/lib/custom \
    && rm grouper.apiBinary-$GROUPER_VERSION.tar.gz grouper.ui-$GROUPER_VERSION.tar.gz grouper.ws-$GROUPER_VERSION.tar.gz grouper.psp-$GROUPER_VERSION.tar.gz grouper.clientBinary-$GROUPER_VERSION.tar.gz
 
COPY seed-data/ /

#MySql shamelessly stolen from https://github.com/dockerfile/mysql/blob/master/Dockerfile
RUN \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server-5.6 && \
  sed -i 's/^\(bind-address\s.*\)/# \1/' /etc/mysql/my.cnf && \
  sed -i 's/^\(log_error\s.*\)/# \1/' /etc/mysql/my.cnf && \
  sed -i 's/\[mysqld\]/\[mysqld\]\ncharacter_set_server = utf8/' /etc/mysql/my.cnf && \
  sed -i 's/\[mysqld\]/\[mysqld\]\ncollation_server = utf8_general_ci/' /etc/mysql/my.cnf && \
  cat  /etc/mysql/my.cnf && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'GRANT ALL PRIVILEGES ON *.* TO \"root\"@\"%\" WITH GRANT OPTION;'" >> /tmp/config && \
  echo "mysql -e 'CREATE DATABASE grouper CHARACTER SET utf8 COLLATE utf8_bin;'" >> /tmp/config && \
  bash /tmp/config && \
  rm -f /tmp/config && \
  mysql grouper < /sisData.sql \
  && echo 'slapd/root_password password password' | debconf-set-selections \
  && echo 'slapd/root_password_again password password' | debconf-set-selections \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y ldap-utils

RUN service slapd start \
    && mkdir -p /var/ldap/example \
    && chown -R openldap /var/ldap \
    && ldapadd -Y EXTERNAL -H ldapi:/// -f init.ldif \
    && ldapadd -Y EXTERNAL -H ldapi:/// -f eduPerson.schema \
    && ldapadd -H ldapi:/// -f users.ldif -x -D "cn=admin,dc=example,dc=edu" -w password 1>/dev/null \
    && rm /*.ldif /eduPerson.schema quickstart.xml
    
COPY opt/ /opt/

RUN set -x; \
    chmod -R +x /opt/container-scripts/; \
    chmod -R +x /opt/apache-tomcat-6.0.44/bin/*.sh; \
    JAVA_HOME=/opt/jdk1.7.0_79; \
    service slapd start \
    && service mysql start \
    && echo Building the wars before patching so embedded api patching works properly \
    && cd /opt/grouper.ui-$GROUPER_VERSION \
    && /opt/apache-ant-1.9.5/bin/ant war \
    && cp dist/grouper.war /opt/apache-tomcat-6.0.44/webapps \
    && cd /opt/grouper.ws-$GROUPER_VERSION/grouper-ws/ \
    && /opt/apache-ant-1.9.5/bin/ant dist \
    && cp build/dist/grouper-ws.war /opt/apache-tomcat-6.0.44/webapps \ 
    && echo Extracting Tomcats war files for patching \
    && mkdir /opt/apache-tomcat-6.0.44/webapps/grouper/ /opt/apache-tomcat-6.0.44/webapps/grouper-ws/ \
    && cd /opt/apache-tomcat-6.0.44/webapps/grouper \
    && $JAVA_HOME/bin/jar xvf ../grouper.war \
    && cd /opt/apache-tomcat-6.0.44/webapps/grouper-ws \
    && $JAVA_HOME/bin/jar xvf ../grouper-ws.war \
    && cd /opt/grouper.apiBinary-$GROUPER_VERSION \
    && bin/gsh -registry -check -runscript -noprompt \
    && mkdir /tmp/grp-api/ /tmp/grp-ui/ /tmp/grp-psp/ /tmp/grp-ws/ \
    && cd / \
    && cp /opt/patch-scripts/grouper.installer-api.properties /grouper.installer.properties \
    && $JAVA_HOME/bin/java -cp .:/grouperInstaller.jar edu.internet2.middleware.grouperInstaller.GrouperInstaller \
    && cd /opt/grouper.apiBinary-$GROUPER_VERSION \
    && bin/gsh -registry -check -runscript -noprompt \
    && bin/gsh /bootstrap.gsh \
    && cd / \
    && cp /opt/patch-scripts/grouper.installer-psp.properties /grouper.installer.properties \
    && $JAVA_HOME/bin/java -cp .:/grouperInstaller.jar edu.internet2.middleware.grouperInstaller.GrouperInstaller \
    && cp /opt/patch-scripts/grouper.installer-ui.properties /grouper.installer.properties \
    && $JAVA_HOME/bin/java -cp .:/grouperInstaller.jar edu.internet2.middleware.grouperInstaller.GrouperInstaller \
    && cp /opt/patch-scripts/grouper.installer-ws.properties /grouper.installer.properties \
    && $JAVA_HOME/bin/java -cp .:/grouperInstaller.jar edu.internet2.middleware.grouperInstaller.GrouperInstaller \
    && rm -fr /tmp/grp-ui/ /tmp/grp-api/ /tmp/grp-psp/ /tmp/grp-ws/

EXPOSE 389 3306 8080

CMD ["run-grouper.sh"]

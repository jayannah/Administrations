#!/bin/bash

#Download jdk
cd /tmp
aws s3 cp s3://$1/bin/jdk-8u73-linux-x64.tar.gz .

#Installing java
ver=1.8.0_73
echo Installing Java ${ver}
tar -xvzf jdk-8u73-linux-x64.tar.gz
mkdir /usr/lib/jvm
mkdir /usr/lib/jvm/oracle_jdk8
mv jdk${ver} /usr/lib/jvm/oracle_jdk8
update-alternatives --install /usr/bin/java java /usr/lib/jvm/oracle_jdk8/jdk${ver}/jre/bin/java 2000
update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/oracle_jdk8/jdk${ver}/bin/javac 2000
update-alternatives --config java
update-alternatives --config javac
echo "export J2SDKDIR=/usr/lib/jvm/oracle_jdk8/jdk${ver}" >> /etc/profile.d/oraclejdk.sh
echo "export J2REDIR=/usr/lib/jvm/oracle_jdk8/jdk${ver}/jre" >> /etc/profile.d/oraclejdk.sh
echo "export PATH=$PATH:/usr/lib/jvm/oracle_jdk8/jdk${ver}/bin:/usr/lib/jvm/oracle_jdk8/jdk${ver}/db/bin:/usr/lib/jvm/oracle_jdk8/jdk${ver}/jre/bin" >> /etc/profile.d/oraclejdk.sh
echo "export JAVA_HOME=/usr/lib/jvm/oracle_jdk8/jdk${ver}" >> /etc/profile.d/oraclejdk.sh
echo "export DERBY_HOME=/usr/lib/jvm/oracle_jdk8/jdk${ver}/db" >> /etc/profile.d/oraclejdk.sh
sh /etc/profile.d/oraclejdk.sh
chmod -R 755 /usr/lib/jvm


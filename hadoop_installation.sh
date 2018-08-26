#!/bin/bash

echo "enter the hadop installation directory"
read Install_Dir

echo "enter the hadoop file location"
read file_loc

echo "enter hadoop installation tar.gz file name"
read file_name

echo "hostname"
read new_hostname


VERSION=$(echo "$file_name" | cut -f 1 -d '.')
HADOOP_Dir=$Install_Dir/hadoop



install_JDK(){
	echo "java version is old or not installed. Installation begins"
	curl -LO -H "Cookie: oraclelicense=accept-securebackup-cookie" "http://download.oracle.com/otn-pub/java/jdk/8u71-b15/jdk-8u71-linux-x64.rpm" 
	rpm -Uvh jdk-8u71-linux-x64.rpm 
	if [ $? != 0 ]
	then
		echo "java installation failed. exiting ..."
}



check_install(){
	 if [ "$EUID" -ne 0 ]
  	 then
  	    echo "Please run as root"
  		exit
	 fi

	 echo "setting hostname" 
	 hostnamectl set-hostname  $new_hostname


	 echo "adding entry to /etc/hosts"
	 ip_a="$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"
	 echo "$ip_a  $new_hostname" >> /etc/hosts


	 file=$file_loc/$file_name
	 if [ -f "$file" ]
	 then
	 	echo "file exists. continuing.."
	 	cp $file /tmp
	 else
	 	echo "installation file doesn't exist. Exiting.."
	 	exit
	 fi


	 
	 if [ -d "$Install_Dir" ]
	 then
	 	echo "folder exists"
	 else
	 	echo "creating sinatallation folder"
	 	mkdir -p $Install_Dir

	 fi

	 echo "extracting the file and moving"
	 cd /tmp
	 tar xfz file_name
	 cp -rf $VERSION $Install_Dir/
	 cd $Install_Dir
	 ln -s $VERSION $Install_Dir/hadoop
	 

	 JAVA_VER=$(java -version 2>&1 | sed -n ';s/.* version "\(.*\)\.\(.*\)\..*"/\1\2/p;')
	[ "$JAVA_VER" -ge 18 ] && echo "ok, java is 1.8 or newer" || install_JDK

}


create_user(){
	adduser -d  $Install_Dir hadoop
	echo "hadoop" | passwd --stdin hadoop
	chown -R hadoop:hadoop $Install_Dir

}


hadoop_config(){
	cat >> $Install_Dir/.bash_profile << EOL
	## JAVA env variables
export JAVA_HOME=/usr/java/default
export PATH=$PATH:$JAVA_HOME/bin
export CLASSPATH=.:$JAVA_HOME/jre/lib:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
## HADOOP env variables
export HADOOP_HOME=/opt/hadoop
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_YARN_HOME=$HADOOP_HOME
export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"
export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native
export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin
EOL

sed -i "s/opt/$Install_Dir/g" $Install_Dir/.bash_profile 
source $Install_Dir/.bash_profile
echo $HADOOP_HOME
echo $JAVA_HOME
}

cat > $Install_Dir/hadoop/etc/hadoop/core-site.xml << EOL

<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
    <configuration>
        <property>
            <name>fs.default.name</name>
            <value>hdfs://localhost:9000</value>
        </property>
    </configuration>
EOL

sed -i "s/localhost/$new_hostname/g"  $Install_Dir/hadoop/etc/hadoop/core-site.xml

cat > $Install_Dir/hadoop/etc/hadoop/hdfs-site.xml << EOL

<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!--
  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License. See accompanying LICENSE file.
-->

<!-- Put site-specific property overrides in this file. -->

<configuration>
    <property>
            <name>dfs.namenode.name.dir</name>
            <value>folder_name/data/nameNode</value>
    </property>

    <property>
            <name>dfs.datanode.data.dir</name>
            <value>folder_name/hadoop/data/dataNode</value>
    </property>

    <property>
            <name>dfs.replication</name>
            <value>1</value>
    </property>
</configuration>
EOL

sed -i "s/folder_name/$Instal_Dir/g"  $Install_Dir/hadoop/etc/hadoop/hdfs-site.xml

}
##YARN configuration
yarn_confg(){
cd $Install_Dir/hadoop/etc/hadoop
cp mapred-site.xml.template mapred-site.xml
cat >> mapred-site.xml << EOL
<configuration>
    <property>
            <name>mapreduce.framework.name</name>
            <value>yarn</value>
    </property>
</configuration>

EOL

cat >> yarn-site.xml << EOL
<configuration>
    <property>
            <name>yarn.acl.enable</name>
            <value>0</value>
    </property>

    <property>
            <name>yarn.resourcemanager.hostname</name>
            <value>localhost</value>
    </property>

    <property>
            <name>yarn.nodemanager.aux-services</name>
            <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOL

sed -i "s/localhost/$new_hostname/g"  yarn-site.xml

}

start_hadoop()
hdfs namenode -format
start-dfs.sh
start-yarn.sh
hdfs dfsadmin -report

main(){
install_JDK
check_install
create_user
hadoop_config
yarn_config
}

main

#!/bin/bash

# Set expected variable values from parameters passed in else apply defaults.
initialize() {

	# Parameters could be passed in as "name=value" strings. Evaluate each in case they are.
	for nv in $@ ; do
		eval "$nv" 2> /dev/null
	done

	# Set default values.
	[ -z "$DB_USERNAME" ] && DB_USERNAME='kcusername'
	[ -z "$DB_PASSWORD" ] && DB_PASSWORD='kcpassword'
	[ -z "$DB_NAME" ] && DB_NAME='kualidb'
	[ -z "$KC_PROJECT_BRANCH" ] && KC_PROJECT_BRANCH='master'
	[ -z "$DB_HOST" ] && DB_HOST='127.0.0.1'
	[ -z "$DB_PORT" ] && DB_PORT='3306'
	[ -z "$WORKING_DIR" ] && WORKING_DIR=$(pwd)
	[ -z "$INSTALL_DEMO_FILES" ] && INSTALL_DEMO_FILES="true"

	if [ ! -d ${WORKING_DIR}/SQL_LOGS ] ; then
	  mkdir -p ${WORKING_DIR}/SQL_LOGS
	fi

	# KC_REPO_URL can be a directory or the github address of the kuali coeus app.
	if [ -d "$KC_REPO_URL" ] ; then
		KC_REPO_DIR=$KC_REPO_URL
	elif [ -z "$KC_REPO_URL" ] ; then
		echo "Missing kuali github repository url or existing directory!!!"
		exit 1
	else
		KC_REPO_DIR="$(echo "$KC_REPO_URL" | grep -Po '[^\/\.]+\.git$' | cut -d'.' -f1)"
	fi
	[ -z "$KC_REPO_DIR" ] && echo "ERROR! Cannot determine repo name from \"${KC_REPO_URL}\"!!!" && exit 1
	
	MYSQL_SQL_FILES_FOLDER="${WORKING_DIR}/${KC_REPO_DIR}/coeus-db/coeus-db-sql/src/main/resources/co/kuali/coeus/data/migration/sql/mysql"

	printf "\nEnvironment variables: \n"
	echo "WORKING_DIR = $WORKING_DIR"
	echo "DB_USERNAME = $DB_USERNAME"
	echo "DB_PASSWORD = $(echo "$DB_PASSWORD" | sed 's/./*/g')"
	echo "DB_NAME = $DB_NAME"
	echo "WORKING_DIR = $WORKING_DIR"
	echo "KC_PROJECT_BRANCH = $KC_PROJECT_BRANCH"
	echo "KC_REPO_URL = $KC_REPO_URL"
	echo "KC_REPO_DIR = $KC_REPO_DIR"
	printf "\n"
}

function exec_sql_scripts() {
	cd $WORKING_DIR
	if [ ! -d $KC_REPO_DIR ] ; then
		git clone ${KC_REPO_URL}
		if [ ! -d $KC_REPO_DIR ] ; then
			echo "ERROR: Could not acquire the github repository: $KC_REPO_URL"
			exit 1
		fi
	fi
	cd ${KC_REPO_DIR}
	if [ "$KC_PROJECT_BRANCH" != "master" ] ; then
	  git checkout $KC_PROJECT_BRANCH
	fi
	cd ${MYSQL_SQL_FILES_FOLDER}
	INSTALL_SQL_VERSION=( $(ls -v *.sql | grep -v INSTALL_TEMPLATE | sed 's/_.*//g' | uniq | sort -n ) )
	for version in ${INSTALL_SQL_VERSION[@]:${1}}
	do
		# INSTALL THE MYSQL FILES
		echo "Installing/upgrading to version ${version}"
		if [ -f ${version}_mysql_rice_server_upgrade.sql ]; then
			mysql \
				--host=$DB_HOST \
				--port=$DB_PORT \
				-u${DB_USERNAME} \
				-p${DB_PASSWORD} \
				${DB_NAME} \
				< ${version}_mysql_rice_server_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_rice_server_upgrade.sql ]; then
			mysql \
				--host=$DB_HOST \
				--port=$DB_PORT \
			  -u${DB_USERNAME} \
				-p${DB_PASSWORD} ${DB_NAME} \
				< ${version}_mysql_kc_rice_server_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_upgrade.sql ]; then
			mysql \
				--host=$DB_HOST \
				--port=$DB_PORT \
				-u${DB_USERNAME} \
				-p${DB_PASSWORD} ${DB_NAME} \
				< ${version}_mysql_kc_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_UPGRADE.log 2>&1
		fi
		# INSTALL THE DEMO FILES
		if [ "${INSTALL_DEMO_FILES,,}" == "true" ] ; then
			if [ -f ${version}_mysql_rice_demo.sql ]; then
				mysql \
					--host=$DB_HOST \
					--port=$DB_PORT \
					-u${DB_USERNAME} \
					-p${DB_PASSWORD} ${DB_NAME} \
					< ${version}_mysql_rice_demo.sql > \
					${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_DEMO.log 2>&1
			fi
			if [ -f ${version}_mysql_kc_demo.sql ]; then
				mysql \
					--host=$DB_HOST \
					--port=$DB_PORT \
					-u${DB_USERNAME} \
					-p${DB_PASSWORD} ${DB_NAME} \
					< ${version}_mysql_kc_demo.sql > \
					${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_DEMO.log 2>&1
			fi
		fi
	done
	# THIS IS TO FIX THE "JASPER_REPORTS_ENABLED" ISSUE BECAUSE THIS SCRIPT DIDN'T RUN IN VERSION 1506
	if [ $(mysql -N -s -u${DB_USERNAME} -p${DB_PASSWORD} -D ${DB_NAME} -e "select VAL from KRCR_PARM_T where PARM_NM='JASPER_REPORTS_ENABLED';" | wc -l) -eq 0 ]; then
		mysql \
			--host=$DB_HOST \
			--port=$DB_PORT \
			-u${DB_USERNAME} \
			-p${DB_PASSWORD} ${DB_NAME} \
			< grm/V602_011__jasper_feature_flag.sql > \
			${WORKING_DIR}/SQL_LOGS/V602_011__JASPER_FEATURE_FLAG.log 2>&1
	fi
	sleep 2
}

function fixBuggyScripts() {
	cd ${MYSQL_SQL_FILES_FOLDER}

  sed -i 's/\(\\\.\)/-- \1/g' 1506_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1506_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1506_mysql_rice_server_upgrade.sql

  sed -i 's/\(\\\.\)/-- \1/g' 1601_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1601_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1601_mysql_rice_server_upgrade.sql

  sed -i 's/\(\\\.\)/-- \1/g' 1603_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1603_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1603_mysql_rice_server_upgrade.sql

	
}

# Check for errors
function check_sql_errors {
	mkdir -p ${WORKING_DIR}/SQL_LOGS
	cp ${WORKING_DIR}/get_*_errors ${WORKING_DIR}/SQL_LOGS
	cd ${WORKING_DIR}/SQL_LOGS
	chmod +x get_*_errors
	./get_mysql_errors
	grep ERROR ${WORKING_DIR}/SQL_LOGS/UPGRADE_ERRORS*

	if [ $? -eq 0 ]; then
		echo
		echo "There were some errors during the install/upgrade. Check ${WORKING_DIR}/SQL_LOGS to make sure"
		sleep 2
		echo "Your database has NOT been upgraded correctly"
	else
		echo
		echo "There were no errors during the install/upgrade. Check ${WORKING_DIR}/SQL_LOGS to make sure"
		sleep 2
		echo "Your database has been upgraded"
	fi
	echo
}
 
initialize $@

exec_sql_scripts

check_sql_errors

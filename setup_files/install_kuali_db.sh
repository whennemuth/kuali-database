#!/bin/bash

# Set expected variable values from parameters passed in else apply defaults.
initialize() {

	# Parameters could be passed in as "name=value" strings. Evaluate each in case they are.
	for nv in $@ ; do
		eval "$nv" 2> /dev/null
	done

	# Set default values.
	[ -z "$KC_DB_USERNAME" ] && KC_DB_USERNAME='kcusername'
	[ -z "$KC_DB_PASSWORD" ] && KC_DB_PASSWORD='kcpassword'
	[ -z "$KC_DB_NAME" ] && KC_DB_NAME='kualidb'
	[ -z "$KC_PROJECT_BRANCH" ] && KC_PROJECT_BRANCH='master'
	[ -z "$KC_DB_HOST" ] && DB_HOST='127.0.0.1'
	[ -z "$KC_DB_PORT" ] && KC_DB_PORT='3306'
	[ -z "$WORKING_DIR" ] && WORKING_DIR=$(pwd)
	[ -z "$INSTALL_DEMO_FILES" ] && INSTALL_DEMO_FILES="true"

	if [ ! -d ${WORKING_DIR}/SQL_LOGS ] ; then
	  mkdir -p ${WORKING_DIR}/SQL_LOGS
	fi

	# KC_REPO_URL=${1:-"https://whennemuth:warrenspassword@github.com/bu-ist/kuali-research.git"}
	[ -z "$KC_REPO_URL" ] && echo "Missing kuali github repository url!!!" && exit 1
	KC_REPO_NAME="$(echo "$KC_REPO_URL" | grep -Po '[^\/\.]+\.git$' | cut -d'.' -f1)"
	[ -z "$KC_REPO_NAME" ] && echo "ERROR! Cannot determine repo name from \"${KC_REPO_URL}\"!!!" && exit 1
	MYSQL_SQL_FILES_FOLDER="${WORKING_DIR}/${KC_REPO_NAME}/coeus-db/coeus-db-sql/src/main/resources/co/kuali/coeus/data/migration/sql/mysql"

	echo "WORKING_DIR = $WORKING_DIR"
	echo "KC_DB_USERNAME = $KC_DB_USERNAME"
	echo "KC_DB_PASSWORD = $KC_DB_PASSWORD"
	echo "KC_DB_NAME = $KC_DB_NAME"
	echo "KC_PROJECT_BRANCH = $KC_PROJECT_BRANCH"
	echo "WORKING_DIR = $WORKING_DIR"
	echo "KC_REPO_URL = $KC_REPO_URL"
	echo "KC_REPO_NAME = $KC_REPO_NAME"
}

function exec_sql_scripts() {
	cd $WORKING_DIR
	if [ ! -d $KC_REPO_NAME ] ; then
	  git clone ${KC_REPO_URL}
	fi
	cd ${KC_REPO_NAME}
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
				--host=$KC_DB_HOST \
				--port=$KC_DB_PORT \
				-u${KC_DB_USERNAME} \
				-p${KC_DB_PASSWORD} \
				${KC_DB_NAME} \
				< ${version}_mysql_rice_server_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_rice_server_upgrade.sql ]; then
			mysql \
				--host=$KC_DB_HOST \
				--port=$KC_DB_PORT \
			  -u${KC_DB_USERNAME} \
				-p${KC_DB_PASSWORD} ${KC_DB_NAME} \
				< ${version}_mysql_kc_rice_server_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_upgrade.sql ]; then
			mysql \
				--host=$KC_DB_HOST \
				--port=$KC_DB_PORT \
				-u${KC_DB_USERNAME} \
				-p${KC_DB_PASSWORD} ${KC_DB_NAME} \
				< ${version}_mysql_kc_upgrade.sql > \
				${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_UPGRADE.log 2>&1
		fi
		# INSTALL THE DEMO FILES
		if [ "${INSTALL_DEMO_FILES,,}" == "true"] ; then
			if [ -f ${version}_mysql_rice_demo.sql ]; then
				mysql \
					--host=$KC_DB_HOST \
					--port=$KC_DB_PORT \
					-u${KC_DB_USERNAME} \
					-p${KC_DB_PASSWORD} ${KC_DB_NAME} \
					< ${version}_mysql_rice_demo.sql > \
					${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_DEMO.log 2>&1
			fi
			if [ -f ${version}_mysql_kc_demo.sql ]; then
				mysql \
					--host=$KC_DB_HOST \
					--port=$KC_DB_PORT \
					-u${KC_DB_USERNAME} \
					-p${KC_DB_PASSWORD} ${KC_DB_NAME} \
					< ${version}_mysql_kc_demo.sql > \
					${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_DEMO.log 2>&1
			fi
		fi
	done
	# THIS IS TO FIX THE "JASPER_REPORTS_ENABLED" ISSUE BECAUSE THIS SCRIPT DIDN'T RUN IN VERSION 1506
	if [ $(mysql -N -s -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} -D ${KC_DB_NAME} -e "select VAL from KRCR_PARM_T where PARM_NM='JASPER_REPORTS_ENABLED';" | wc -l) -eq 0 ]; then
		mysql \
			--host=$KC_DB_HOST \
			--port=$KC_DB_PORT \
			-u${KC_DB_USERNAME} \
			-p${KC_DB_PASSWORD} ${KC_DB_NAME} \
			< grm/V602_011__jasper_feature_flag.sql > \
			${WORKING_DIR}/SQL_LOGS/V602_011__JASPER_FEATURE_FLAG.log 2>&1
	fi
	sleep 2
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

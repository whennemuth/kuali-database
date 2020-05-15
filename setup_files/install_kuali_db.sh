#!/bin/bash

# Settings
CURRENT_WORKING_DIR=$(pwd)

KC_DB_USERNAME="kcusername"
KC_DB_PASSWORD="kcpassword"
KC_DB_NAME="kualicoeusdb"

# KC_REPO_URL=${1:-"https://whennemuth:warrenspassword@github.com/bu-ist/kuali-research.git"}
KC_REPO_URL="$1"
[ -z "$KC_REPO_URL" ] && echo "Missing kuali github repository url!!!" && exit 1
KC_REPO_NAME="$(echo "$KC_REPO_URL" | grep -Po '[^\/\.]+\.git$' | cut -d'.' -f1)"
[ -z "$KC_REPO_URL" ] && echo "ERROR! Cannot determine repo name from \"${KC_REPO_URL}\"!!!" && exit 1
KC_PROJECT_BRANCH=${2:-"master"}
MYSQL_SQL_FILES_FOLDER="${CURRENT_WORKING_DIR}/${KC_REPO_NAME}/coeus-db/coeus-db-sql/src/main/resources/co/kuali/coeus/data/migration/sql/mysql"

function exec_sql_scripts() {
	git clone ${KC_REPO_URL}
	cd ${CURRENT_WORKING_DIR}/${KC_REPO_NAME}
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
			mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < ${version}_mysql_rice_server_upgrade.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_rice_server_upgrade.sql ]; then
			mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < ${version}_mysql_kc_rice_server_upgrade.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_RICE_SERVER_UPGRADE.log 2>&1
		fi
		if [ -f ${version}_mysql_kc_upgrade.sql ]; then
			mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < ${version}_mysql_kc_upgrade.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_UPGRADE.log 2>&1
		fi
		# INSTALL THE DEMO FILES
		 		if [ -f ${version}_mysql_rice_demo.sql ]; then
		 			mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < ${version}_mysql_rice_demo.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_DEMO.log 2>&1
	  		fi
		 		if [ -f ${version}_mysql_kc_demo.sql ]; then
		 			mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < ${version}_mysql_kc_demo.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_DEMO.log 2>&1
		 		fi
	done
	# THIS IS TO FIX THE "JASPER_REPORTS_ENABLED" ISSUE BECAUSE THIS SCRIPT DIDN'T RUN IN VERSION 1506
	if [ $(mysql -N -s -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} -D ${KC_DB_NAME} -e "select VAL from KRCR_PARM_T where PARM_NM='JASPER_REPORTS_ENABLED';" | wc -l) -eq 0 ]; then
		mysql -u${KC_DB_USERNAME} -p${KC_DB_PASSWORD} ${KC_DB_NAME} < grm/V602_011__jasper_feature_flag.sql > ${CURRENT_WORKING_DIR}/SQL_LOGS/V602_011__JASPER_FEATURE_FLAG.log 2>&1
	fi
	sleep 2
}

# Check for errors
function check_sql_errors {
	mkdir -p ${CURRENT_WORKING_DIR}/SQL_LOGS
	cp ${CURRENT_WORKING_DIR}/get_*_errors ${CURRENT_WORKING_DIR}/SQL_LOGS
	cd ${CURRENT_WORKING_DIR}/SQL_LOGS
	chmod +x get_*_errors
	./get_mysql_errors
	grep ERROR ${CURRENT_WORKING_DIR}/SQL_LOGS/UPGRADE_ERRORS*

	if [ $? -eq 0 ]; then
		echo
		echo "There were some errors during the install/upgrade. Check ${CURRENT_WORKING_DIR}/SQL_LOGS to make sure"
		sleep 2
		echo "Your database has NOT been upgraded correctly"
	else
		echo
		echo "There were no errors during the install/upgrade. Check ${CURRENT_WORKING_DIR}/SQL_LOGS to make sure"
		sleep 2
		echo "Your database has been upgraded"
	fi
	echo
}

function setup_kuali_database {
	mkdir -p ${CURRENT_WORKING_DIR}/SQL_LOGS
	# Run the SQL Scripts
	exec_sql_scripts
	# Check for errors
	check_sql_errors
}

# Run the Kuali SQL files
setup_kuali_database

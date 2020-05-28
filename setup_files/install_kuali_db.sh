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

	if [ -d ${WORKING_DIR}/SQL_LOGS ] ; then
	  rm -rf ${WORKING_DIR}/SQL_LOGS
	fi
	mkdir -p ${WORKING_DIR}/SQL_LOGS
	
	# KC_REPO_URL can be a directory or the github address of the kuali coeus app.
	if [ -d "$KC_REPO_URL" ] ; then
		KC_REPO_DIR=$KC_REPO_URL
		MYSQL_SQL_FILES_FOLDER="${KC_REPO_DIR}/coeus-db/coeus-db-sql/src/main/resources/co/kuali/coeus/data/migration/sql/mysql"
		INGESTION_XML_DIR="${KC_REPO_DIR}/coeus-db/coeus-db-xml/src/main/resources"
	elif [ -n "$KC_REPO_URL" ] ; then
		KC_REPO_DIR="$(echo "$KC_REPO_URL" | grep -Po '[^\/\.]+\.git$' | cut -d'.' -f1)"
		if [ -z "$KC_REPO_DIR" ] ; then
			echo "ERROR! \"$KC_REPO_URL\" is not a directory or a git url."
			exit 1;
		fi
		MYSQL_SQL_FILES_FOLDER="${WORKING_DIR}/${KC_REPO_DIR}/coeus-db/coeus-db-sql/src/main/resources/co/kuali/coeus/data/migration/sql/mysql"
		INGESTION_XML_DIR="${WORKING_DIR}/${KC_REPO_DIR}/coeus-db/coeus-db-xml/src/main/resources"
	else
		echo "Missing kuali github repository url or existing directory!!!"
		exit 1
	fi
	[ -z "$KC_REPO_DIR" ] && echo "ERROR! Cannot determine repo name from \"${KC_REPO_URL}\"!!!" && exit 1
	

	printf "\nEnvironment variables: \n"
	echo "WORKING_DIR = $WORKING_DIR"
	echo "MYSQL_SQL_FILES_FOLDER = $MYSQL_SQL_FILES_FOLDER"
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

	fixBuggyScripts
	
	INSTALL_SQL_VERSION=( $(ls -v *.sql | grep -v INSTALL_TEMPLATE | sed 's/_.*//g' | uniq | sort -n ) )
	for version in ${INSTALL_SQL_VERSION[@]:${1}} ; do
		# INSTALL THE MYSQL FILES
		echo "Installing/upgrading to version ${version}"

		runScript 'rice_server' "$version"
		runScript 'kc_rice_server' "$version"
		runScript 'kc' "$version"

		if [ "${INSTALL_DEMO_FILES,,}" == "true" ] ; then
			runScript 'rice_demo' "$version"
			runScript 'kc_demo' "$version"
		fi
	done

	fixBuggyScriptResults

	sleep 2
}

# Construct the pieces of a mysql command depending on parameters and run the command.
function runScript() {
	local module="$1"
	local version="$2"
	case "$module" in
		kc)
			local sqlfile="${version}_mysql_kc_upgrade.sql"
			local logfile="${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_UPGRADE.log"
			;;
		rice_server)
			local sqlfile="${version}_mysql_rice_server_upgrade.sql"
			local logfile="${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_SERVER_UPGRADE.log"
			;;
		kc_rice_server)
			local sqlfile="${version}_mysql_kc_rice_server_upgrade.sql"
			local logfile="${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_RICE_SERVER_UPGRADE.log"
			;;
		kc_demo)
			local sqlfile="${version}_mysql_kc_demo.sql"
			local logfile="${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_KC_DEMO.log"
			;;
		rice_demo)
			local sqlfile="${version}_mysql_rice_demo.sql"
			local logfile="${WORKING_DIR}/SQL_LOGS/${version}_MYSQL_RICE_DEMO.log"
			;;
	esac
  
	if [ -f "$sqlfile" ] ; then
		if [ "$sqlfile" == '1905_mysql_kc_rice_server_upgrade.sql' ] ; then
		  # Seems to be the only workable approach to fixing crazy ERROR 1064 – sqlstate 42000
			# encountered when running this file. No syntax issues are evident, but you get this
			# error unless you run each listed sql file individually. Cause of issue still unknown.
			runIndividually $sqlfile $logfile
		else
	    mysqlRun $sqlfile $logfile
		fi
	fi
}

# Execute a single mysql command.
function mysqlRun() {
	local sqlfile="$1"
	local logfile="$2"
	echo "  -- $sqlfile"
	mysql --host=$DB_HOST --port=$DB_PORT -u${DB_USERNAME} -p${DB_PASSWORD} ${DB_NAME} < $sqlfile > $logfile 2>&1
	# if [ $? -gt 0 ] ; then
	#   cat $logfile
	# 	exit 1
	# fi
}

# Mysql .sql files are modified here before being run so as to prevent the runtime errors they will cause.
function fixBuggyScripts() {
	cd ${MYSQL_SQL_FILES_FOLDER}

	# If a git repo, stash any changes get a clean working tree 
	git status -s > /dev/null 2>&1
	if [ $? -eq 0 ] ; then
		git stash
	fi

  sed -i 's/\(\\\.\)/-- \1/g' 1506_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1506_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1506_mysql_rice_server_upgrade.sql

  sed -i 's/\(\\\.\)/-- \1/g' 1601_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1601_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1601_mysql_rice_server_upgrade.sql

  sed -i 's/\(\\\.\)/-- \1/g' 1603_mysql_rice_server_upgrade.sql
	sed -i "s/\\(commit\\)/select 'Skipping 1603_mysql_rice_server_upgrade.sql' AS '';\\n\\1/" 1603_mysql_rice_server_upgrade.sql

  sed -i '21 a \\\. ./kc/bootstrap/V1901_002__nsf_cover_page_1_9_fix.sql' 1901_mysql_kc_upgrade.sql

  cat <<EOF > ./kc/bootstrap/V1901_002__nsf_cover_page_1_9_fix.sql
	  -- Preparatory fix for upcoming ./kc/bootstrap/V1901_002__nsf_cover_page_1_9.sql
	  update question set question_id = (question_id * -1) where question_id in (10110, 10111, 10112);
EOF

	# Need to "ERROR 1832 (HY000)" thrown when modifying a column with a foreign key constraint.
  # Only happens with aurora-rds, and setting the "foreign_key_checks" system variable  to "0" globally seems to get 
	# countermanded somehow if you are running mysql in rds. So, setting foreign_key_checks off at top of all .sql files.
	sqlfiles=( 
		kc/bootstrap/*.sql
		rice/bootstrap/*.sql
		rice_server/bootstrap/*.sql
		rice_data_only/bootstrap/*.sql
		grm/*.sql
	)
	echo "Setting foreign_key_checks = 0 for all *.sql files..."
	for sqlfile in ${sqlfiles[@]} ; do
	  echo -en "\r$sqlfile"
		sed -i '1s;^;SET FOREIGN_KEY_CHECKS = 0\;\n;' $sqlfile;
	done;	
}

# Those mysql .sql files that could not be corrected before being run will have produced results that need to be corrected after being run.
function fixBuggyScriptResults() {
	# THIS IS TO FIX THE "JASPER_REPORTS_ENABLED" ISSUE BECAUSE THIS SCRIPT DIDN'T RUN IN VERSION 1506
	if [ $(mysql -N -s -u${DB_USERNAME} -p${DB_PASSWORD} -D ${DB_NAME} -e "select VAL from KRCR_PARM_T where PARM_NM='JASPER_REPORTS_ENABLED';" | wc -l) -eq 0 ]; then
	  mysqlRun \
		  grm/V602_011__jasper_feature_flag.sql \
			${WORKING_DIR}/SQL_LOGS/V602_011__JASPER_FEATURE_FLAG.log
	fi

	# Turn on dashboard mode because it defaults to false.
	mysql -N -s -u${DB_USERNAME} -p${DB_PASSWORD} -D ${DB_NAME} -e \
		"UPDATE `kualidb`.`krcr_parm_t` SET `VAL` = 'true' WHERE (`PARM_NM` = 'Dashboard_Mode_Enabled');"

	# If a git repo, trash any changes made to scripts and restore anything stashed before scripts were run
	git status -s > /dev/null 2>&1
	if [ $? -eq 0 ] ; then
		git reset --hard HEAD
		git stash pop
	fi
}

function runIndividually() {
	cd ${MYSQL_SQL_FILES_FOLDER}
	sqlfile="$1"
	logfile="$2"
  while read -r line; do 
    if [ "${line:0:5}" == '\. ./' ] ; then
      mysqlRun "${line:3}" $logfile;
    fi
  done < $sqlfile
}

# Check for errors
function check_sql_errors {
	cd ${WORKING_DIR}/SQL_LOGS

	# Search each log file for errors and place all results into a single dated file
	FileName=UPGRADE_ERRORS.`eval date +%Y%m%d"."%H.%M`
	for f in *.log;
	do 
		echo >> $FileName
		echo "Processing $f file.."
		echo [ $f ] >> $FileName
		cat $f | grep -B5 -A3 ERROR >> $FileName
	done

	# Grep the errors file for the term ERROR - if found, report that there were errors.
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

ZipInstalled() {
  git --version > /dev/null 2>&1 && [ "$?" == "0" ] && true || false
}

function create_ingestion_zip_files() {
	if ! ZipInstalled ; then
		echo "Ingestion xml files not prepared because zip program is not installed."
		return 1
	fi
	if [ -d /tmp ] ; then
		local targetdir='/tmp'
	elif [ -d "$WORKING_DIR" ] ; then
		local targetdir="$WORKING_DIR"
	else
	  local targetdir="$(pwd)"
	fi
	cd $INGESTION_XML_DIR

	echo "Zipping $targetdir/ingest-rice.zip..."
	zip -r $targetdir/ingest-rice.zip org/kuali/coeus/rice-xml 1> /dev/null
	echo "Zipping $targetdir/ingest-coeus-1-3.zip, dir 1..."
	zip -r $targetdir/ingest-coeus-1-3.zip org/kuali/coeus/coeus-xml/1 1> /dev/null
	echo "Zipping $targetdir/ingest-coeus-1-3.zip, dir 2..."
	zip -r -u $targetdir/ingest-coeus-1-3.zip org/kuali/coeus/coeus-xml/2 1> /dev/null
	echo "Zipping $targetdir/ingest-coeus-1-3.zip, dir 3..."
	zip -r -u $targetdir/ingest-coeus-1-3.zip org/kuali/coeus/coeus-xml/3 1> /dev/null
	echo "Zipping $targetdir/ingest-coeus-4.zip..."
	zip -r $targetdir/ingest-coeus-4.zip org/kuali/coeus/coeus-xml/4 1> /dev/null

	echo "When kc is running, navigate to: System Admin --> XML Ingester, and ingest these zip file in the order printed above."
}
 
initialize $@

exec_sql_scripts

check_sql_errors

create_ingestion_zip_files
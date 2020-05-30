## Kuali Coeus Database for docker or RDS

This repository is based on and extends: [https://github.com/jefferyb/docker-mysql-kuali-coeus](https://github.com/jefferyb/docker-mysql-kuali-coeus)

The purpose is to create a mysql database for the kuali-research application to connect to in one of two ways:

1. ### **Dockerized:**

   During a docker image build:

   1. Mysql is installed.
   2. The git repository that contains the kuali research application is cloned to acquire all of the mysql database scripts that bring the database from a blank state all the way up to the current state as of the HEAD of the repo.
   3. setup_files\install_kuali_db.sh is run to execute each script from oldest to newest against the mysql database.

   Once the image is built, you can run a container against it with port 3306 published or exposed.
   Then, the kuali-research application can be run locally from an IDE or in another docker container and is configured to connect to the  database container.
       

   **To use:**

   Script: docker.sh

   Methods: 

   - build
     Parameters:
     - KC_REPO_URL
       Specifies the github repository for the kuali coeus application. If the github repository is private, the provide it like this:
       `https://your_username:your_password@github.com/bu-ist/kuali-research.git`
       *Required: No, default: "https://github.com/bu-ist/kuali-research.git"*
     - KC_PROJECT_BRANCH
       Specifies the branch to check out from the kuali coeus github repo once cloned.
       *Required: No, default: "master"*
   - run
     Parameters: NONE

   ```
   # 1) Acquire this repository:
   git clone https://github.com/bu-ist/kuali-database.git
   cd kuali-database
   
   # 2) Build the mysql database image example:
   sh docker.sh build \
       "KC_REPO_URL=https://your_username:your_password@github.com/bu-ist/kuali-research.git" \
       "KC_PROJECT_BRANCH=bu-master"
       
       # Or use default values:
       sh docker.sh build
   
   # 3) Run the mysql database image:
   sh docker.sh run
   
   # 4) [Optional] If running the container on a remote server, tunnel to it to run mysql commands locally. Example:
   ssh -i ~/.ssh/buaws-kuali-rsa-warren -N -v -L 3306:10.57.237.89:3306 ec2-user@10.57.237.89
   
   # 5) Test the database with a query (requires mysql client installed):
   mkdir ingestion_xml && \
   mysql \
       -u root \
       -h 127.0.0.1 \
       -v $(pwd)/ingestion_xml:/tmp
       --password=password123 \
       kualidb \
       -e "show tables;"
   ```

   *NOTE: Step number 2 above  has an optional second parameter - it will default to "master" if not provided, but it indicates the branch that will checked out from the cloned kuali-research git repository.*

   **Ingestion:**
   You can at this point run the kc application against this database. However, you cannot create any workflows yet. this is because more database content needs to be "ingested".
   If you mounted the /tmp directory of the container to one you create on the host, you will find 3 zip files in that directory:

   1. ingest-rice.zip
   2. ingest-coeus-1-3.zip
   3. ingest-coeus-4.zip

   Navigate to: System Admin --> XML Ingester, and ingest these zip files in the order listed above.

      

2. ### **Mysql-aurora in Amazon RDS**

   The database is built as an Amazon mysql-aurora RDS database as follows:

   1. A cloudformation template is run to create a single node RDS cluster.
   2. The git repository that contains the kuali research application is cloned to acquire all of the mysql database scripts that bring the database from a blank state all the way up to the current state as of the HEAD of the repo. 
   3. setup_files\install_kuali_db.sh is run to execute each script from oldest to newest against the RDS cluster.
   4. The kuali-research application can be run locally from an IDE or in another container and is configured to connect to the RDS cluster.
          
   
   **To use (stack operations):**
   
   Script: rds.sh
   
   Methods: 
   
   - create
   - update
   - delete
   - validate
   
   Parameters:
   
   - STACK_NAME:
      Specifies the name to give to a stack when creating it, or the name of the stack to update/delete. *Methods: create, update, delete*
      *Required: No, Default: "kuali-aurora-mysql-rds"*
   - DB_PASSWORD:
      Specifies either a raw password or the path of a kc-config.xml file in S3 from which will be extracted for the password you want to apply for access to the rds database.
      *Methods: create, update, delete*
      *Required: No, Default: "s3://kuali-research-ec2-setup/sb/kuali/main/config/kc-config-rds.xml"*
   
   ```
   # 1) Acquire this repository if not already:
   git clone https://github.com/bu-ist/kuali-database.git
   cd kuali-database
       
   # 2) Optional: If you have made changes to the yaml template, you can validate them.
   sh rds.sh validate
      
   # 3) Create the rds cluster through cloudformation 
   S3_BUCKET="kuali-research-ec2-setup" && \
   sh rds.sh create \
       "STACK_NAME=kuali-aurora-mysql-rds" \
       "DB_PASSWORD=s3://kuali-research-ec2-setup/sb/kuali/main/config/kc-config-rds.xml"
   
       # The parameters shown above happen to be the defaults, so the equivalent is:
       sh rds.sh rds create
   
       # To update a stack that has already been created:
       sh rds.sh update "STACK_NAME=kuali-aurora-mysql-rds"
   
       # And to delete the stack:
       sh rds.sh delete "STACK_NAME=kuali-aurora-mysql-rds"
   ```
   
   ​    
   
   **To use (database initialization/population):**
   
   Script: rds.sh
   
   Methods: 
   
   - populate
   
   Parameters:
   
   - STACK_NAME:
     The name of the cloudformation stack in which the rds database was created.
     With this stack name known, each of the following parameters can be determined via an AWS CLI call for stack outputs. 
     *Required: No, default "kuali-aurora-mysql-rds"*
     - DB_HOST:
       The name of the host for the kuali-research database cluster. This would have been one of the outputs of the rds cluster stack creation.
       *Required: [If no stack exists for lookup that matches provided STACK_NAME or its default value]*
     - DB_NAME:
       The name of the kuali-research database.
       *Required: No, default: successful stack lookup value using provided STACK_NAME or its default value, else: "kualidb"*
     - DB_USERNAME:
       The name of the kuali-research database user.
       *Required: No, default: successful stack lookup value using provided STACK_NAME or its default value, else: "kcusername"*
     - DB_PORT:
       The port to connect to the kuali-research database over.
       *Required: No, default: successful stack lookup value using provided STACK_NAME or its default value, else: 3306*
   - DB_PASSWORD:
     The password for the kuali-research database user. You can provide the raw password, or you can provide the path of a file in S3 that contains the password.
     *Required: Yes*
   - KC_REPO_URL:
     Specifies the github repository for the kuali coeus application. If the github repository is private, the provide it like this:
     `https://your_username:your_password@github.com/bu-ist/kuali-research.git`
     *Required: No, default: "https://github.com/bu-ist/kuali-research.git"*
   - KC_PROJECT_BRANCH:
     The kuali-research git repository branch to checkout for the sql scripts to run.
     *Required: No, default: master*
   - INSTALL_DEMO_FILES:
     Specifies whether or not to add additional demo entries into the database once created.
     *Required: No, default: true*
   - WORKING_DIR:
     The root folder, containing a subfolder of the cloned github repo for the kuali-research app (or where it is to be cloned if it does not already exist)
     *Required: No, default: [current directory]*
   
   ```
    1) Acquire this repository if not already:
   git clone https://github.com/bu-ist/kuali-database.git
   cd kuali-database
   
   # 2) Create and populate the kuali-research database in the rds cluster (EXAMPLE):
   sh rds.sh populate \
       "KC_REPO_URL=https://github.com/bu-ist/kuali-research" \
       "DB_USERNAME=kcusername" \
       "DB_PASSWORD=s3://kuali-research-ec2-setup/sb/kuali/main/config/kc-config-rds.xml" \
       "DB_NAME=kualidb" \
       "KC_PROJECT_BRANCH=bu-master" \
       "DB_HOST=http://kuali-aurora-mysql-rds-databasecluster-j4nektrwrrd6.cluster-cnc9dm5uqxog.us-east-1.rds.amazonaws.com/" \
       "DB_PORT=3306" \
       "WORKING_DIR=$(pwd)" \
       "INSTALL_DEMO_FILES='true'"
   
   # or exclude db parameters and include STACK_NAME to get them via a stack output lookup:
   sh rds.sh populate \
       "KC_REPO_URL=https://github.com/bu-ist/kuali-research" \
       "DB_PASSWORD=s3://kuali-research-ec2-setup/sb/kuali/main/config/kc-config-rds.xml" \
       "KC_PROJECT_BRANCH=bu-master" \
       "WORKING_DIR=$(pwd)" \
       "INSTALL_DEMO_FILES='true'"
   
   # This example uses default stack output lookup results and defaults all remaining values:
   sh rds.sh populate
   
   # This example does the same as the last, except specifys a directory for the git repo:
   sh rds.sh populate \
     "KC_REPO_URL=/c/some/path/kuali-research"
   ```
   
   

   **Ingestion:**
   You can at this point run the kc application against this database. However, you cannot create any workflows yet. this is because more database content needs to be "ingested".
   If you mounted the /tmp directory of the container to one you create on the host, you will find 3 zip files in that directory:
   
   1. ingest-rice.zip
   2. ingest-coeus-1-3.zip
   3. ingest-coeus-4.zip
   
   Navigate to: System Admin --> XML Ingester, and ingest these zip files in the order listed above.




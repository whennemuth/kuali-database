### Kuali Coeus Database for docker or RDS

This repository is based on and extends: [https://github.com/jefferyb/docker-mysql-kuali-coeus](https://github.com/jefferyb/docker-mysql-kuali-coeus)

The purpose is to create a mysql database for the kuali-research application to connect to in one of two ways:

1. #### **Dockerized:**

   During a docker image build:

   - Mysql is installed.
   - The git repository that contains the kuali research application is cloned to acquire all of the mysql database scripts that bring the database from a blank state all the way up to the current state as of the HEAD of the repo.
   - setup_files\install_kuali_db.sh is run to execute each script from oldest to newest against the mysql database.
   - A container is run against the image with port 3306 published or exposed.
   - The kuali-research application can be run locally from an IDE or in another container and is configured to connect to the  database running from the container.


   **To use:**

   ```
   # 1) Acquire this repository:
   git clone https://github.com/jefferyb/docker-mysql-kuali-coeus.git
   cd docker-mysql-kuali-coeus
   
   # 2) Build the mysql database image example:
   sh docker.sh build \
     "https://your_username:your_password@github.com/bu-ist/kuali-research.git" \
     "bu-master"
     
   # 3) Run the mysql database image:
   sh docker.sh run
   
   # 4) Test the database with a query (requires mysql client installed):
   mysql \
     -u root \
     -h 127.0.0.1 \
     --password=password123 \
     kualidb \
     -e "show tables;"
   ```

   *NOTE: Step number 2 above  has an optional second parameter - it will default to "master" if not provided, but it indicates the branch that will checked out from the cloned kuali-research git repository.*

2. #### **Mysql-aurora in Amazon RDS**

   The database is built as an Amazon mysql-aurora RDS database as follows:

   - A cloudformation template is run to create a single node RDS cluster.
   - The git repository that contains the kuali research application is cloned to acquire all of the mysql database scripts that bring the database from a blank state all the way up to the current state as of the HEAD of the repo. 
   - setup_files\install_kuali_db.sh is run to execute each script from oldest to newest against the RDS cluster.
   - The kuali-research application can be run locally from an IDE or in another container and is configured to connect to the RDS cluster.


   **To use (stack operations):**

   Parameters:

   - STACK_TASK:
     Specifies if the stack operation (create, update, or delete)
   - STACK_NAME:
     Specifies the name to give to a stack when creating it, or the name of the stack to update/delete. 
   - DB_PASSWORD:
     Specifies the path of a file in S3 that contains the password you want to apply for access to the rds database.

   ```
   # 1) Acquire this repository:
   git clone https://github.com/jefferyb/docker-mysql-kuali-coeus.git
   cd docker-mysql-kuali-coeus
   
   # 2) Create the rds cluster through cloudformation 
       S3_BUCKET="kuali-research-ec2-setup" && \
       sh rds.sh create \
         "STACK_NAME=kuali-aurora-mysql-rds" \
         "DB_PASSWORD=s3://kuali-research-ec2-setup/rds/password1"
     
       # The parameters shown above happen to be the defaults, so the equivalent is:
       sh rds.sh rds
   
       # To update a stack that has already been created:
       sh rds.sh update \
         "STACK_NAME=kuali-aurora-mysql-rds" \
         "DB_PASSWORD=s3://kuali-research-ec2-setup/rds/password1"
   
       # And to delete the stack:
       sh rds.sh delete "STACK_NAME=kuali-aurora-mysql-rds"
   ```


   **To use (database creation/population):**

   Parameters:

   - DB_USERNAME:
     The name of the kuali-research database user.
     *Required: No, default kcusername*
   - DB_PASSWORD:
     The password for the kuali-research database user. You can provide the raw password, or you can provide the path of a file in S3 that contains the password.
     *Required: Yes*
   - DB_NAME:
     The name of the kuali-research database.
     *Required: No, default: kualidb*
   - DB_HOST:
     The name of the host for the kuali-research database cluster. This would have been one of the outputs of the rds cluster stack creation.
     *Required: Yes*
   - DB_PORT:
     The port to connect to the kuali-research database over.
     *Required: No, default: 3306*
   - KC_PROJECT_BRANCH:
     The kuali-research git repository branch to checkout for the sql scripts to run.
     *Required: No, default: master*
   - INSTALL_DEMO_FILES:
     Specifies whether or not to add additional demo entries into the database once created.
     *Required: No, default: true*
   - WORKING_DIR:
     The root folder, containing a subfolder of the cloned github repo for the kuali-research app (or where it is to be cloned if it does not already exist)

   ```
   # Create and populate the kuali-research database in the rds cluster:
   sh rds.sh populate \
     "KC_REPO_URL=https://github.com/bu-ist/kuali-research" \
     "DB_USERNAME=kcusername" \
     "DB_PASSWORD=s3://kuali-research-ec2-setup/rds/password1" \
     "DB_NAME=kualidb" \
     "KC_PROJECT_BRANCH=bu-master" \
     "DB_HOST=http://kuali-aurora-mysql-rds-databasecluster-j4nektrwrrd6.cluster-cnc9dm5uqxog.us-east-1.rds.amazonaws.com/" \
     "DB_PORT=3306" \
     "WORKING_DIR=$(pwd)" \
     "INSTALL_DEMO_FILES='true'"
     
     # or use defaults.
     sh rds.sh populate 
   ```

   


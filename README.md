# me-mysql-cron
Bash tool to import/export MySQL databases (Windows/Unix)

### 1. Introduction
Export & import MySQL databases from the command line. The connection details are stored in config files. Main use is to set up automatic crons/tasks.

### 2. Configuration
Setup & test the connection details by following the wizard
```sh
./cron.setup.sh
-----------------------------------------------
  Main Menu
-----------------------------------------------
  1 = Select Config
  2 = Create/Update Config
...............................................
  0 = Exit
-----------------------------------------------
  Choose a number? 2

-----------------------------------------------
  Create/Update Config
...............................................
  Current Configs:
  - test.cfg
-----------------------------------------------
  Config details
  Name: test2
  Are you sure you want to create 'test2.cfg'? (y/n) y

-----------------------------------------------
  Config Wizard 'test2.cfg'
-----------------------------------------------
  1 = Password
  2 = Dump Folder Path
  3 = Notify Email Address
  4 = Max Dumps
  5 = Source Database
  6 = Target Database 1
  7 = Target Database 2
  8 = All (1-7)
...............................................
  9 = Save Changes
...............................................
  0 = Main Menu
-----------------------------------------------

***********************************************
* Recommended: 8 = All (1-7)                   *
***********************************************

  Choose a number? 8
```

### 3. Exporting
Create a full export of the source database. Includes schema, data, & routines.
```sh
./cron.driver.sh -c 'configs/my_config.cfg' -a 'export' -p 'myPassword'
```
- Creates a new directory in [my_config.cfg->DUMP_FOLDER_NAME]
- Does a complete export of the database into the new directory
- Compresses & removes the new directory, if 'zip' is available
- Appends a records to the log file (export.log)

### 4.a. Importing (Single target database)
Imports the latest dump file into the target database after clearing it.
```sh
./cron.driver.sh -c 'configs/my_config.cfg' -a 'import' -p 'myPassword'
```
- Checks the latest dump file in [my_config.cfg->DUMP_FOLDER_NAME]
- Clears the database defined in the config file
- Imports the latest dump file


### 4.b. Importing (Alternating target databases)
Imports the latest dump file into the (inactive) target database after clearing it. Ensures that there will always be a live version of the target database available. Use case: QA environments.
```sh
./cron.driver.sh -c 'configs/my_config.cfg' -a 'import' -p 'myPassword'
```
- Checks the latest dump file in [my_config.cfg->DUMP_FOLDER_NAME]
- Selects the appropriate target database.
-- Even Week = Database 1
-- Odd Week = Database 2
- Clears the database defined in the config file
- Imports the latest dump file


### 5. Config File
```ini
SECURITYGUID="myPassword"
DUMP_FOLDER_NAME="dumps/my_prod_dumps"
NOTIFY_EMAIL_ADDRESS="johndoe@company.com"

# Source Database Details
DB_SOURCE_HOST=""
DB_SOURCE_USER=""
DB_SOURCE_NAME=""
DB_SOURCE_PASS=""

# Target Databases Details
# Target Database 1 - Used on weeks that are 'odd'
DB_TARGET_1_HOST=""
DB_TARGET_1_USER=""
DB_TARGET_1_NAME=""
DB_TARGET_1_PASS=""

# Target Database 2 - Used on weeks that are 'even'
DB_TARGET_2_HOST=""
DB_TARGET_2_USER=""
DB_TARGET_2_NAME=""
DB_TARGET_2_PASS=""
```
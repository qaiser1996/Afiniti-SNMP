# Table of Content
 - Deploying snmp Agent With Custom OIDs
     - Installing and Configuring net-snmp
     - Installing and Configuring snmpd
     - Extending snmpd Using Shell Scripts
       - Adding OID to Get Software Version 
       - Adding OID to Get Disk Space Taken by /var/log Directory
       - Adding OID to Get Latest Signal Value From PostgreSQL Database
    - Design Approach and Choice
    - Testing
    - Problems Faced
    - Alternate Approach
    - Time Division

# Deploying snmp Agent With Custom OIDs
In this I have deployed an SNMP agent and created have created three custom OIDs for specific purposes which will be mentioned later in detail. The SNMP agent runs on a linux machine and provides information to SNMP manager upon request. Following is the step by step breakdown of how I did the task after doing my initial research on snmp.

# Installing and Configuring net-snmp
  - Download latest version of net-snmp from [sourceforge](https://sourceforge.net/projects/net-snmp/files/net-snmp/5.8/)
  - Extract resources `tar -xvzf net-snmp-5.8.tar.gz`.
  - Install dependency
  `sudo apt-get update`
  `sudo apt-get install libperl-dev`.
  - Go to net-snmp folder `cd net-snmp-5.8`.
  - Configure with this command `./configure --with-default-snmp-version="3" --with-sys-contact="@@no.where" --with-sys-location="Unknown" .
--with-logfile="/var/log/snmpd.log" --with-persistent-directory="/var/net-snmp"`.
  - Compile using `make` this will take some time.
  - Now install `sudo make install`.
  - Finally install `sudo apt-get install snmp-mibs-downloader`
  - Open `/etc/snmp/snmp.conf`
    comment out this line `mibs:` to this `# mibs`.
It should look like this
    ```
    # As the snmp packages come without MIB files due to license reasons, loading
    # of MIBs is disabled by default. If you added the MIBs you can reenable
    # loading them by commenting out the following line.
    # mibs :
    
    # If you want to globally change where snmp libraries, commands and daemons
    # look for MIBS, change the line below. Note you can set this for individual
    # tools with the -M option or MIBDIRS environment variable.
    #
    # mibdirs /usr/share/snmp/mibs:/usr/share/snmp/mibs/iana:/usr/share/snmp/mibs/ietf
    ```

After successfully installing net-snmp, verify by running this command `snmpget --version`
```
NET-SNMP version: 5.8
```

# Installing and Configuring snmpd
  - Install snmpd `sudo apt-get install snmpd`
  - Go to `cd etc/snmp`
  - Open `snmpd.conf` file using `sudo nano snmpd.conf`
  - Edit this line or comment out
    ```
    agentAddress  udp:127.0.0.1:161
    ```
    and add this
    ```
    agentAddress udp:161,udp6:[::1]:161
    ```
    This is to tell snmp daemon to accept connections over ports 161
    
  - Change community string
    ```
    # Read-only access to everyone to the systemonly view
    rocommunity  public default -V systemonly
    rocommunity6 public default -V systemonly
    ```
    to
    ```
    # Read-only access to everyone to the systemonly view
    rocommunity afiniti default
    rocommunity6 afiniti default
    ```
    We have removed -V systemonly because it restricts view to only `SNMPv2-MIB` MIB.
  - Add users at the and of this file
    ```
    rwuser qaiserDES
    
    createUser qaiserDES MD5 "password" DES
    ```
    
  - Restart snmpd `sudo systemctl restart snmpd` (Note: Remember this command as it will be used everytime snmpd.conf is edited)
    
    After successfully installing and configuring run `snmpwalk -v2c -c afiniti 127.0.0.1 sysUpTime.0` it should give the following output
       ```
       DISMAN-EVENT-MIB::sysUpTimeInstance = Timeticks: (20437) 0:03:24.37
       ```
    
# Extending snmpd Using Shell Scripts

# Adding OID to Get Software Version

Returns a static string "Software Version Number is 6.1.1"

 - Shell script (`afinitiVersion.sh`):
    ```
    #! /bin/bash -e
    
    echo "Software Version Number is 6.1.1"
    exit 0
    ```
    
  - Adding extend in `/etc/snmp/snmpd.conf` (Use this format `extend [OID] <extName> </dir/binary> </dir/script> <arguments>`)
      ```
      extend .1.3.6.1.4.1.53864 version /home/qaiser/Documents/afiniti/afinitiVersion.sh
      ```
      OID: `.1.3.6.1.4.1.<PEN>`
  - Restart snmpd `sudo systemctl restart snmpd`
  Test by running this command `snmpget -v3 -u qaiserDES -l authPriv -a MD5 -x DES -A password -X password 127.0.0.1 SNMPv2-SMI::enterprises.53864.3.1.1.\"version\"`
  Output:
    ```
    SNMPv2-SMI::enterprises.53864.3.1.1.7.118.101.114.115.105.111.110 = STRING: "Software Version Number is 6.1.1"
    ```
# Adding OID to Get Disk Space Taken by /var/log Directory

Returns "<dir path> total disk usage: <bytes> bytes"

 - Shell script (`afinitiLogSize.sh`):
    ```
    #! /bin/bash

    # checking empty parameters
    if [ $# -eq 0 ]; then
        # if parameters are empty echo usage prompt <path/to/dir>
        echo "usage: <path/to/dir>"
        exit 1
    fi
    
    folder="$1"
    
    # checking if passed dir path exists
    if [ -d $folder ] 
    then
        # store results du command and ignoring access denied message in an array
        du_results_array=(`du $folder --max-depth=1 2> >(grep -v 'Permission denied')`)
        # get array length
        du_results_array_length=${#du_results_array[@]}
        # echo second last element in the array which is Total space used
        echo "$folder total disk usage: "${du_results_array[$du_results_array_length-2]} "bytes"
        exit 0
    else
        # if path does not exist
        echo "Error: Directory path does not exists."
        exit 101
    fi
    ```
    
  - Adding extend in `/etc/snmp/snmpd.conf` (Use this format `extend [OID] <extName> </dir/binary> </dir/script> <arguments>`)
      ```
      extend .1.3.6.1.4.1.53864 disk /home/qaiser/Documents/afiniti/afinitiLogSize.sh /var/log
      ```
      OID: `.1.3.6.1.4.1.<PEN>`
  - Restart snmpd `sudo systemctl restart snmpd`
  Test by running this command `snmpget -v3 -u qaiserDES -l authPriv -a MD5 -x DES -A password -X password 127.0.0.1 SNMPv2-SMI::enterprises.53864.3.1.1.\"disk\"`
  Output:
    ```
    SNMPv2-SMI::enterprises.53864.3.1.1.4.100.105.115.107 = STRING: "/var/log total disk usage: 38448 bytes"
    ```
    
# Adding OID to Get Latest Signal Value From PostgreSQL Database
Returns "Signal Value: <value>"
  - Install postgreSql by this command `sudo apt-get install postgresql postgresql-contrib`
  - Add user by executing these commands:
    ```
    sudo -u postgres psql
    postgres=# create database afinititest;
    postgres=# create user mqaiser with encrypted password 'password';
    postgres=# grant all privileges on database afinititest to mqaiser;
    ```
    
  - Create table in database and insert values using following SQL queries (`database.sql`)
    ```
    CREATE TABLE snmpsignals(signalTime timestamp PRIMARY KEY, signalValue int);
    INSERT into snmpsignals VALUES (to_timestamp('01-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),12);
    INSERT into snmpsignals VALUES (to_timestamp('02-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),13);
    INSERT into snmpsignals VALUES (to_timestamp('03-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),18);
    INSERT into snmpsignals VALUES (to_timestamp('04-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),20);
    INSERT into snmpsignals VALUES (to_timestamp('05-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),25);
    INSERT into snmpsignals VALUES (to_timestamp('06-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),33);
    INSERT into snmpsignals VALUES (to_timestamp('07-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),31);
    INSERT into snmpsignals VALUES (to_timestamp('08-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),27);
    INSERT into snmpsignals VALUES (to_timestamp('09-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),16);
    INSERT into snmpsignals VALUES (to_timestamp('10-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),13);
    INSERT into snmpsignals VALUES (to_timestamp('11-05-2020 00:00:00', 'dd-mm-yyyy hh24:mi:ss'),10);
      ```
 - Shell script (`afinitiSignalSQL.sh`):
    ```
    #! /bin/bash

    # loading database crdentials
    # source .env
    # Contents of .env, as it is not pushed to repo for security, I'm putting it's contents here for understanding also when using snmpget, it can't find .env file but executing it in bash does.
    HOST="127.0.0.1"
    POSTGRES_PORT="5432"
    DATABASE="afinititest"
    USERNAME="mqaiser"
    PASSWORD="password"
    
    # execute SQL query and storing result in array
    sql="SELECT signalValue FROM snmpSignals order by signalTime DESC Limit 1;"
    signal_results_array=(`psql --command="$sql" postgresql://$USERNAME:$PASSWORD@$HOST:$PORT/$DATABASE`)
    # get array length
    signal_esults_array_length=${#signal_results_array[@]}
    # echo third last element in the array which is Total space used
    echo "Signal Value: "${signal_results_array[2]}
    exit 0
    ```
    
  - Adding extend in `/etc/snmp/snmpd.conf` (Use this format `extend [OID] <extName> </dir/binary> </dir/script> <arguments>`)
      ```
      extend .1.3.6.1.4.1.53864 signal /home/qaiser/Documents/afiniti/afinitiSignalSQL.sh
      ```
      OID: `.1.3.6.1.4.1.<PEN>`
  - Restart snmpd `sudo systemctl restart snmpd`
  Test by running this command `snmpget -v3 -u qaiserDES -l authPriv -a MD5 -x DES -A password -X password 127.0.0.1 SNMPv2-SMI::enterprises.53864.3.1.1.\"signal\"`
  Output:
    ```
    SNMPv2-SMI::enterprises.53864.3.1.1.6.115.105.103.110.97.108 = STRING: "Signal Value: 10"
    ```

# Problems Faced
These are the major problems that I had to face, there were others as well but they weren't so difficult to overcome.
  - Unable to start snmpd service:
    - Reason: Existance of `libsnmp` files in two or more directories
      - Solution: Deleting duplicate lib files
  - Unable to access OID/MIB after extending
    - Reason: Restricted access
        - Solution: removed `-V systemonly` from `snmpd.conf` in `rocummunity` command
  - Unable to connect to PostgreSQL:
    - Reason: Multiple errors in Postgres server
      - Soulution: Re-Installed Postgresql
  - Getting "Permission Denied" while getting disk usage of /var/log
    - Reason: Some sub-directories had restricted access
        - Solution: In `du` command added `--max-depth=1 2> >(grep -v 'Permission denied')`
         Full command: `du $folder --max-depth=1 2> >(grep -v 'Permission denied')`
  - Operationg system crashed:
    - Reason: Unknown
        - Solution Re-installed linux
  - In snmpd the files in `afinitiSignalSQL.sh` such `.env` and `query.sql` were not loaded
    - Reason: Unknown
      - Solution: Merged the files in one shell script file `afinitiSignalSQL.sh`

# Time Division
 - Time spent on research: 20%
 - Time spent on getting linux installed and configuration: 5%
 - Time spent on setting up snmp and snmpd: 5%
 - Time spent on coding the solution: 20%
 - Time spent on solving errors, problems and bugs: 50%


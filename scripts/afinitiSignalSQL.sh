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

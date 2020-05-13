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

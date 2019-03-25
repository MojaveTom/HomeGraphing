#!/bin/bash
##  Shell script to run RetrieveAmbientWeatherData twice a day.
##    Runs every 12 hours. (local time)

## if there is an "at" job scheduled for this program, remove it before starting another.
for j in $(at -l | cut -f1)  # get a list of pids for my "at" jobs.
do
  # The last lines of the script restart it; extract the file name from the script.
  jobFile=$(at -c $j | tail -n4 | grep 'at -f.*\.sh')  # Get the line with the at command
  jobFile=${jobFile#*at -f}			# Eliminate the beginning
  jobFile=${jobFile%% *}			# Eliminate everything after the first space
  if [ -n "$jobFile" ]      # ignore empty jobFiles
  then
    if [ "$jobFile" = "${0##*/}" ]      # if the file name from the "at" script matches us
    then                            # remove it from the list
#      echo "$jobFile is pid $j"
      at -r $j
    fi
  fi
done

####   MAKE SURE THERE IS A LINK TO THE CURRENT EXECUTABLE -- not the .app
#### WHERE THIS SCRIPT EXPECTS IT TO BE.
$PWD/RetrieveAmbientWeatherData.py
# Get time as num secs, round to next higher 15 minutes [add 3 min] (900 sec); print as HHMM
nextTime=$(date -jr $(( ($(date -j +%s) / 900 + 1 ) * 900 + 180 )) "+%H%M")

# Reschedule this script to run at the nextTime.  Throw stdout and stderr in bit bucket.
at -fScheduleRetrieveAmbientData.sh $nextTime >/dev/null 2>&1

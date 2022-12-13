#!/bin/bash
# Startup the custom deck sync for Loto Quebec
# REMEMBER: we are using the basic date package in alpine
# could be a delay in minutes or an absolute time of day

# Load in functions for this startup script
. ./functions.sh

# Establish variables for runtime and set defaults
DS_RUN_FREQ=${DS_RUN_FREQ:-5}
DS_RUN_ONCE=${DS_RUN_ONCE:-false}
DS_RUN_BEGIN=${DS_RUN_BEGIN:-+1}
DS_FILE_NAME=${DS_FILE_NAME:-dump.yaml}
DS_FILE_PATH=${DS_FILE_PATH:-/tmp}
VERBOSE=${VERBOSE:-false}
if [ $VERBOSE == "true" ]; then
  set -x
fi

# Startup variables for the loop
CURRENT_TIME=$(date +"%s")
LAST_RUN=0
FREQ_TIME=$(($DS_RUN_FREQ*60)) # convert the global frequency to seconds
WAITTIME=0
EXIT_CODE=0
REGEX_FOR_BEGIN_TIME="^\+(.*)$"

# Calculate the wait time and exact start time
# Respect the order:
# 1. DS_RUN_ONCE
# 2. DS_RUN_CRON
# 3. DS_RUN_BEGIN
# 4. inheart DS_RUN_BEGIN by default too at 1 minute
if [ $DS_RUN_ONCE == "true" ]; then
  if [[ $DS_RUN_BEGIN =~ $REGEX_FOR_BEGIN_TIME ]]; then
    WAITTIME=$(( ${BASH_REMATCH[1]} * 60 ))
  fi
elif [ -n "$DS_RUN_CRON" ]; then
  # Calculate how long until the next cron instance is met
  WAITTIME=$(wait_for_cron "$DS_RUN_CRON" "$CURRENT_TIME" $LAST_RUN)
  TARGET_TIME=$(($CURRENT_TIME + $WAITTIME))
elif [[ $DS_RUN_BEGIN =~ $REGEX_FOR_BEGIN_TIME ]]; then
  WAITTIME=$(( ${BASH_REMATCH[1]} * 60 ))
  TARGET_TIME=$(($CURRENT_TIME + $WAITTIME))
else
  TODAY=$(date +"%Y-%m-%d")
  target_time=$(date --date="${TODAY} ${DS_RUN_BEGIN}" +"%s")

  if [[ "$TARGET_TIME" < "$CURRENT_TIME" ]]; then
    TARGET_TIME=$(($TARGET_TIME + 24*60*60))
  fi

  WAITTIME=$(($TARGET_TIME - $CURRENT_TIME))
fi

# Post message in stdout
echo "Starting at $(date --date=@${TARGET_TIME})"
sleep $WAITTIME

# Start the loop
while true; do
  # Make sure the directory exists
  mkdir -p $DS_FILE_PATH
  # Run dump and sync
  bash dump-and-sync.sh
  # Capture exit code to inheart if possible
  [ $? -ne 0 ] && EXIT_CODE=1
  # Remove lingering file
  /bin/rm ${DS_FILE_PATH}/${DS_FILE_NAME}

  # Calculation for the wait time
  CURRENT_TIME=$(date +"%s")
  # Exit for one time run
  if [ $DS_RUN_ONCE == "true" ]; then
    exit $EXIT_CODE
  # If crontab expres is set then have it calculate waittime
  elif [ -n "${DS_RUN_CRON}" ]; then
    WAITTIME=$(wait_for_cron "${DS_RUN_CRON}" "$CURRENT_TIME" $LAST_RUN)
    TARGET_TIME=$(($CURRENT_TIME + $WAITTIME))
    # Else using the FREQ_TIME value
  else
    CURRENT_TIME=$(date +"%s")
    # Calculate how long the previous backup took
    BACKUP_TIME=$(($CURRENT_TIME - $TARGET_TIME))
    # Calculate how many times the frequency time was passed during the previous backup.
    FREQ_TIME_COUNT=$(($BACKUP_TIME / $FREQ_TIME))
    # Increment the count with one because we want to wait at least the frequency time once.
    FREQ_TIME_COUNT_TO_ADD=$(($FREQ_TIME_COUNT + 1))
    # Calculate the extra time to add to the previous target time
    EXTRA_TIME=$(($FREQ_TIME_COUNT_TO_ADD*$FREQ_TIME))
    # Calculate the new target time needed for the next calculation
    TARGET_TIME=$(($TARGET_TIME + $EXTRA_TIME))
    # Calculate the wait time
    WAITTIME=$(($TARGET_TIME - $CURRENT_TIME))
  fi
  LAST_RUN=$(date +"%s")
  echo "Rerunning at $(date --date=@${TARGET_TIME})"
  sleep $WAITTIME
done
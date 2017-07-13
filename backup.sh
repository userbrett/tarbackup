#!/bin/bash
#
# backup.sh
#
# This is the script that creates the backups.
#
# Sample cron entry:
# /root/bin/backup/backup.sh daily 2>&1 |\
#           grep -v "Removing leading"|mail -s'Daily' user@domain
#
# The backup process is as follows:
# - Source the appropriate config file in this directory.
# - In directory order:
#   - Parse the first file that is linked via the $1 directory.
#     - Using the sample above, $1 would be the "daily" directory.
#   - If an "extra" script is found in the jobs directory, run it.
#   - If an "exclude" file in found in the jobs directory, use it.
#   - Perform the backup as specified by that modules configuration.
#   - Repeat for the remaining files that are sym linked.
#
# You should not need to edit this file.
# - Instead, make changes to inclusions, exclusions and scripts in 
#   in the jobs and periods (daily, weekly, etc.) directories.
#
#
# NOTE:
# --------------------------
# This application has been developed with the expectation that a full
# "archive" backup will be taken on the first of every month, and
# that any weekly, daily, or even hourly backups will be differential
# backups since the 1st of the month.  In other words, anything that
# is not a monthly backup will result in only backing up files that
# have been modified since the first of the month.
# ----------------------------------------------------------------------


usage() {
  echo "Usage: $0 <monthly|weekly|daily|hourly>"
  exit
}

[ -z $1 ] && usage


# print header
BACKUPTYPE=$1
export BACKUPTYPE
echo "Running backup: $BACKUPTYPE"

# import config
if [ "$BACKUPTYPE" = "monthly" ] ; then
  if [ -e /root/bin/backup/config-full ]; then
    . /root/bin/backup/config-full
  else
    echo "Config file not found in current directory."
    echo "Exiting."
    exit
  fi
else
  if [ -e /root/bin/backup/config-diff ]; then
    . /root/bin/backup/config-diff
  else
    echo "Config file not found in current directory."
    echo "Exiting."
    exit
  fi
fi

export TODAY THISDAY BACKUPHOST BACKUPTO SCRIPTDIR

# and execute
for JOB in `ls ${SCRIPTDIR}/${BACKUPTYPE}/*`
do
  # import job config
  . ${SCRIPTDIR}/${BACKUPTYPE}/${JOB##*/}

  # check for an exclude file
  eval EXCLUDEFILE=\${SCRIPTDIR}/jobs/\${JOB##*/}.exclude
  EXCLUDE=""
  if [ -e ${EXCLUDEFILE} ]; then
    echo "setting up exclude file"
    EXCLUDE="-X ${EXCLUDEFILE}"
  fi

  # engage
  echo; echo "Running:"

  mkdir -p ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY}

  # check for extra script to run
  eval EXTRASCRIPT=\${SCRIPTDIR}/jobs/\${JOB##*/}.script
  if [ -e ${EXTRASCRIPT} ]; then
    echo; echo "Extra script found, running:"
    echo "${EXTRASCRIPT}"
    ${EXTRASCRIPT}
  fi

  if [ "$BACKUPTYPE" = "monthly" ] ; then

    # Perform full backup
    echo "Running: tar zcf ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY}/${JOB##*/}-${TODAY}.tgz ${EXCLUDE} ${BACKUPFROM}"
    tar zcf ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY}/${JOB##*/}-${TODAY}.tgz ${EXCLUDE} ${BACKUPFROM}

  else

    # Perform differential backup
    echo "find ${BACKUPFROM} -type f -daystart -mtime -${THISDAY} | perl -p -i -e 's/([ ])/\\\1/g' |\
        /usr/bin/xargs tar zcf ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY}/${JOB##*/}-${TODAY}.tgz ${EXCLUDE}"

    find ${BACKUPFROM} -type f -daystart -mtime -${THISDAY} | perl -p -i -e 's/([ ])/\\\1/g' |\
        /usr/bin/xargs tar zcf ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY}/${JOB##*/}-${TODAY}.tgz ${EXCLUDE}

  fi

done


# print footer
echo; echo; echo "SUMMARY:"
ls -l ${BACKUPTO}/${BACKUPHOST}/${BACKUPHOST}-${BACKUPTYPE}-${TODAY} | awk '{print $5,$6,$7,$8,$9}'
echo; echo "END SUMMARY"

exit 0

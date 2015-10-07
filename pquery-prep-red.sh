#!/bin/bash
# Created by Roel Van de Paar, Percona LLC
# The name of this script (pquery-prep-red.sh) was kept short so as to not clog directory listings - it's full name would be ./pquery-prepare-reducer.sh, 
# not unlike prepare-reducer.sh. Yet, prepare-reducer.sh is for RQG trials while this one is for pquery trials. It's runtime is quite different.

# To aid with correct bug to testcase generation for pquery trials, this script creates a local run script for reducer and sets #VARMOD#.
# This handles crashes/asserts for the moment only. Could be expanded later for other cases, and to handle more unforseen situations.

# User variables
REDUCER="$(echo ~)/percona-qa/reducer.sh"

# Internal variables
SCRIPT_PWD=$(cd `dirname $0` && pwd)
WORKD_PWD=$PWD

# User variables
REDUCER="${SCRIPT_PWD}/reducer.sh"

# Check if this is a pxc run
if [ "$1" == "pxc" ]; then
  PXC=1
else
  PXC=0
fi

# Check if this an automated (pquery-reach.sh) run
if [ "$1" == "reach" ]; then
  REACH=1  # Minimal output, and no 2x enter required
else
  REACH=0  # Normal output
fi

# Variable checks
if [ ! -r ${REDUCER} ]; then
  echo "Something is wrong: this script could not read reducer.sh at ${REDUCER} - please set REDUCER variable inside the script correctly."
  exit 1
fi
# Current location checks
if [ `ls ./*/pquery_thread-[1-9]*.sql 2>/dev/null | wc -l` -gt 0 ]; then
  echo -e "** NOTE ** Multi-threaded trials (./*/pquery_thread-[1-9]*.sql) were found. For multi-threaded trials, now the 'total sql' file containing all executed queries (as randomly generated by pquery-run.sh prior to pquery's execution) is used. Reducer scripts will be generated as per normal (with the relevant multi-threaded options already set), and they will be pointed to these (i.e. one file per trial) SQL testcases. Failing sql from the coredump and the error log will be auto-added (interleaved multile times) to ensure better reproducibility. A new feature has also been added to reducer.sh, allowing it to reduce multi-threaded testcases multi-threadely using pquery --threads=x, each time with a reduced original (and still random) sql file. If the bug reproduces, the testcase is reduced further and so on. This will thus still end up with a very small testcase, which can be then used in combination with pquery --threads=x.\n"
  MULTI=1
fi
if [ `ls ./*/pquery_thread-0.sql 2>/dev/null | wc -l` -eq 0 ]; then
  echo "Something is wrong: there were 0 pquery sql files found (./*/pquery_thread-0.sql) in subdirectories of the current directory. Terminating."
  exit 1
fi
NEW_MYEXTRA_METHOD=0
if [ `ls ./*/MYEXTRA 2>/dev/null | wc -l` -gt 0 ]; then  # New MYEXTRA/MYSAFE variables pass & VALGRIND run check method as of 2015-07-28 (MYSAFE & MYEXTRA stored in a text file inside the trial dir, VALGRIND file created if used)
  echo "Using the new (2015-07-28) method for MYEXTRA/MYSAFE variables pass & VALGRIND run check method. All settings will be set automatically for each trial (and can be checked below)!"
  NEW_MYEXTRA_METHOD=1
  MYEXTRA=
  VALGRIND_CHECK=
elif [ `ls ./pquery-run.log 2>/dev/null | wc -l` -eq 0 ]; then  # Older (backward compatible) methods for retrieving MYEXTRA/MYSAFE
  echo -e "Something is wrong: this script did not find a file ./pquery-run.log (the main pquery-run log file) in this directory. Was this run generated by pquery-run.sh?\n"
  echo -e "WARNING: Though this script does not necessarily need the ./pquery-run.log file to obtain the MYEXTRA and MYSAFE settings (MYEXTRA are extra settings passed to mysqld, MYSAFE is similar but it is specifically there to ensure QA tests are of a reasonable quality), PLEASE NOTE that if any MYEXTRA/MYSAFE=\"....\" settings were used when using pquery-run.sh, then these settings will now not end up in the reducer<nr>.sh scripts that this script produces. The result is likely that some issues will not reproduce as mysqld was not started with the same settings... If you have the original pquery-run.sh script as you used it to generate this workdir, you could extract the MYEXTRA and MYSAFE strings from there, compile them into one and add them to the reducer<nr>.sh scripts that do not reproduce, which is an easy/straightforward solution. Yet, if you want to re-generate all reducer<nr>.sh scripts with the right settings in place, just copy the MYEXTRA and MYSAFE lines and add them to a file called ./pquery-run.log as follows:\n"
  echo "MYEXTRA: --some_option --some_option_2 etc. (Important: ensure all is on one line with no line breaks!)"
  echo "MYSAFE: --some_option --some_option_2 etc. (Important: ensure all is on one line with no line breaks!)"
  echo "Then, re-run this script. It will extract the MYEXTRA/MYSAFE settings from the ./pquery-run.log and use these in the resulting reducer<nr>.sh scripts. Make sure to have the syntax exactly matches the above, with quotes (\") removed etc."
  if [ -r ${SCRIPT_PWD}/pquery-run.sh ]; then
    MYEXTRA="`grep '^[ \t]*MYEXTRA[ \t]*=[ \t]*"' ${SCRIPT_PWD}/pquery-run.sh | sed 's|^[ \t]*MYEXTRA[ \t]*=[ \t]*"[ \t]*||;s|#.*$||;s|"[ \t]*$||'`"
    MYSAFE="`grep '^[ \t]*MYSAFE[ \t]*=[ \t]*"'  ${SCRIPT_PWD}/pquery-run.sh | sed 's|^[ \t]*MYSAFE[ \t]*=[ \t]*"[ \t]*||;s|#.*$||;s|"[ \t]*$||'`"
    echo -e "Now, to make it handy for you, this script has already pre-parsed the pquery-run.sh found here: ${SCRIPT_PWD}/pquery-run.sh (is this the one you used?) and compiled the following MYEXTRA and MYSAFE settings from it:\n"
    echo "MYEXTRA: $MYEXTRA"
    echo "MYSAFE: $MYSAFE"
    echo -e "\nIf this is the script (and thus MYEXTRA/MYSAFE) settings you used, hit enter 3x now and we will use these settings. However, if you are not sure if ${SCRIPT_PWD}/pquery-run.sh was the script you used, or the MYEXTRA/MYSAFE settings shown above do not look correct then press CTRL-C to abort now. Please note one other gotcha here: if you did a bzr pull since your ${SCRIPT_PWD}/pquery-run.sh run, it is possible and even regularly 'likely' that your MEXTRA settings were changed to whatever is in the percona-qa tree (and they have been changing...). Thus, be sure before you hit enter twice. Also, it would make sense to make a copy of pquery-run.sh (pquery-run-<date>.sh for example) and save it in the workdir as a backup. If you use a version of pquery-run.sh later then 16-10-2014, then pquery-run.sh already auto-saves a copy of itself in the workdir. Note: this script (pquery-prep-red.sh) may be extended further later to check for the saved copy of pquery-run.sh."
      echo "Btw, note that only MYEXTRA is used by reducer, so MYSAFE string is compiled into MYEXTRA."
    read -p "Press ENTER or CTRL-C now... 1..."
    read -p "Press ENTER or CTRL-C now... 2..."
    read -p "Press ENTER or CTRL-C now... 3..."
    echo "Ok, using MYEXTRA/MYSAFE as listed above"
    MYEXTRA="$MYEXTRA $MYSAFE"
  else
    echo "If you would like this script to continue *WITHOUT* any MYEXTRA and MYSAFE settings (i.e. some issues will likely fail to reproduce), hit enter 3x now. If you would like to take one of the two approaches listed above (though note we could not locate a pquery-run.sh in ${SCRIPT_PWD} which is another oddity), press CTRL-C and action as described."
    echo "Btw, note that only MYEXTRA is used by reducer, so MYSAFE string is compiled into MYEXTRA, which in this case simply results in an empty string."
    read -p "Press ENTER or CTRL-C now... 1..."
    read -p "Press ENTER or CTRL-C now... 2..."
    read -p "Press ENTER or CTRL-C now... 3..."
    echo "Ok, using empty MYEXTRA/MYSAFE (Note that only MYEXTRA is used by reducer, so MYSAFE string is compiled into MYEXTRA)"
    MYEXTRA=""
    MYSAFE=""  # This and the next line are not needed, just leaving them here for if logic comprehension / if they ever need something added etc.
    MYEXTRA="$MYEXTRA $MYSAFE"
  fi
else
  MYEXTRA="`grep 'MYEXTRA:' ./pquery-run.log | sed 's|^.*MYEXTRA[: \t]*||'`"
  MYSAFE="`grep 'MYSAFE:' ./pquery-run.log | sed 's|^.*MYSAFE[: \t]*||'`"
  VALGRIND_CHECK="`grep 'Valgrind run:' ./pquery-run.log | sed 's|^.*Valgrind run[: \t]*||' | awk '{print $1}'`"
  if [ ${REACH} -eq 0 ]; then # Avoid normal output if this is an automated run (REACH=1)
    echo "Using the following MYEXTRA/MYSAFE settings (found in the ./pquery-run.log stored in this directory):"
    echo "======================================================================================================================================================"
    echo "MYEXTRA: $MYEXTRA"
    echo "MYSAFE: $MYSAFE"
    echo "======================================================================================================================================================"
    echo "If you agree that these look correct, hit enter twice. If something looks wrong, press CTRL+C to abort."
    echo "(Note that MYSAFE was only introduced around 13-10-2014, so it would be empty for earlier runs before this date"
    echo "(To learn more, you may want to read some of the info/code in this script (pquery-prep-red.sh) in the 'Current location checks' var checking section.)"
    echo "Btw, note that only MYEXTRA is used by reducer, so MYSAFE string will be merged into MYEXTRA for the resulting reducer<nr>.sh scripts."
    echo "======================================================================================================================================================"
    read -p "Press ENTER or CTRL-C now... 1..."
    read -p "Press ENTER or CTRL-C now... 2..."
    echo "Ok, using MYEXTRA/MYSAFE as listed above"
  fi
  MYEXTRA="$MYEXTRA $MYSAFE"
fi

#Check MS/PS pquery binary
#PQUERY_BIN="`grep 'pquery Binary' ./pquery-run.log | sed 's|^.*pquery Binary[: \t]*||'`"    # < swap back to this one once old runs are gone
PQUERY_BIN=$(echo "$(grep -im1 "PQUERY_BIN=" *pquery*.sh | sed 's|[ \t]*#.*$||;s|PQUERY_BIN=||')" | sed "s|\${SCRIPT_PWD}|${SCRIPT_PWD}|")

if [ "${PQUERY_BIN}" == "" ]; then
  echo "Assert! pquery binary used could not be auto-determined. Check script around \$PQUERY_BIN initialization."
  exit 1
fi

extract_queries_core(){
  echo "* Obtaining quer(y)(ies) from the trial's coredump (core: ${CORE})"
  . ${SCRIPT_PWD}/pquery-failing-sql.sh ${TRIAL} 1
  if [ "${MULTI}" == "1" ]; then
    CORE_FAILURE_COUNT=`cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing | wc -l`
    echo "  > $[ $CORE_FAILURE_COUNT ] quer(y)(ies) added with interleave sql function to the SQL trace"
  else
    for i in {1..3}; do
      BEFORESIZE=`cat ${INPUTFILE} | wc -l`
      cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing >> ${INPUTFILE}
      AFTERSIZE=`cat ${INPUTFILE} | wc -l`
    done
    echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"
    rm -Rf ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing
  fi
}
  
extract_queries_error_log(){
  # Extract the "Query:" crashed query from the error log (making sure we have the 'Query:' one at the end)
  echo "* Obtaining quer(y)(ies) from the trial's mysqld error log (if any)"
  . ${SCRIPT_PWD}/pquery-failing-sql.sh ${TRIAL} 2
  if [ "${MULTI}" == "1" ]; then
    FAILING_SQL_COUNT=`cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing | wc -l`
    echo "  > $[ $FAILING_SQL_COUNT - ${CORE_FAILURE_COUNT} ] quer(y)(ies) will be added with interleave sql function to the SQL trace"
  else
    for i in {1..3}; do
      BEFORESIZE=`cat ${INPUTFILE} | wc -l`
      cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing >> ${INPUTFILE}
      AFTERSIZE=`cat ${INPUTFILE} | wc -l`
    done
    echo "  > $[ $AFTERSIZE - $BEFORESIZE ] quer(y)(ies) added 3x to the SQL trace"
    rm -Rf ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing
  fi
}

auto_interleave_failing_sql(){
  # sql interleave function based on actual input file size
  INPUTLINECOUNT=`cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.backup | wc -l`
  FAILING_SQL_COUNT=`cat ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing | wc -l`
  if [ $FAILING_SQL_COUNT -ge 10 ]; then
    if [ $INPUTLINECOUNT -le 100 ]; then
      sed -i "0~5 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    elif [ $INPUTLINECOUNT -le 500 ];then
      sed -i "0~25 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    elif [ $INPUTLINECOUNT -le 1000 ];then
      sed -i "0~50 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    else
      sed -i "0~75 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    fi
  else
    if [ $INPUTLINECOUNT -le 100 ]; then
      sed -i "0~3 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    elif [ $INPUTLINECOUNT -le 500 ];then
      sed -i "0~15 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    elif [ $INPUTLINECOUNT -le 1000 ];then
      sed -i "0~35 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    else
      sed -i "0~50 r ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing" ${INPUTFILE}
    fi
  fi
}

generate_reducer_script(){
  if [ "$TEXT" == "" -o "$TEXT" == "my_print_stacktrace" -o "$TEXT" == "0" -o "$TEXT" == "NULL" ]; then  # Too general strings, or no TEXT found, use MODE=4
    MODE=4
    TEXT_CLEANUP="s|ZERO0|ZERO0|"  # A zero-effect change (de-duplicates #VARMOD# code below)
    TEXT_STRING1="s|ZERO0|ZERO0|"
    TEXT_STRING2="s|ZERO0|ZERO0|"
  else  # Bug-specific TEXT string found, use MODE=3 to let reducer.sh reduce for that specific string
    if [ "$VALGRIND_CHECK" == "TRUE" ]; then
      MODE=1
    else
      MODE=3
    fi
    TEXT_CLEANUP="0,/^[ \t]*TEXT[ \t]*=.*$/s|^[ \t]*TEXT[ \t]*=.*$|#TEXT=<set_below_in_machine_variables_section>|"
    TEXT_STRING1="0,/#VARMOD#/s:#VARMOD#:# IMPORTANT NOTE; Leave the 3 spaces before TEXT on the next line; pquery-results.sh uses these\n#VARMOD#:"
    TEXT_STRING2="0,/#VARMOD#/s:#VARMOD#:   TEXT=\"${TEXT}\"\n#VARMOD#:"
  fi
  if [ "$MYEXTRA" == "" ]; then  # Empty MYEXTRA string
    MYEXTRA_CLEANUP="s|ZERO0|ZERO0|"
    MYEXTRA_STRING1="s|ZERO0|ZERO0|"  # Idem as above
  else  # MYEXTRA specifically set
    MYEXTRA_CLEANUP="0,/^[ \t]*MYEXTRA[ \t]*=.*$/s|^[ \t]*MYEXTRA[ \t]*=.*$|#MYEXTRA=<set_below_in_machine_variables_section>|"
    MYEXTRA_STRING1="0,/#VARMOD#/s:#VARMOD#:MYEXTRA=\"${MYEXTRA}\"\n#VARMOD#:"
  fi
  if [ "$MULTI" != "1" ]; then  # Not a multi-threaded pquery run
    MULTI_CLEANUP="s|ZERO0|ZERO0|"  # Idem as above
    MULTI_CLEANUP2="s|ZERO0|ZERO0|"
    MULTI_CLEANUP3="s|ZERO0|ZERO0|"
    MULTI_STRING1="s|ZERO0|ZERO0|"
    MULTI_STRING2="s|ZERO0|ZERO0|"
    MULTI_STRING3="s|ZERO0|ZERO0|"
  else  # Multi-threaded pquery run
    MULTI_CLEANUP1="0,/^[ \t]*PQUERY_MULTI[ \t]*=.*$/s|^[ \t]*PQUERY_MULTI[ \t]*=.*$|#PQUERY_MULTI=<set_below_in_machine_variables_section>|"
    MULTI_CLEANUP2="0,/^[ \t]*FORCE_SKIPV[ \t]*=.*$/s|^[ \t]*FORCE_SKIPV[ \t]*=.*$|#FORCE_SKIPV=<set_below_in_machine_variables_section>|"
    MULTI_CLEANUP3="0,/^[ \t]*FORCE_SPORADIC[ \t]*=.*$/s|^[ \t]*FORCE_SPORADIC[ \t]*=.*$|#FORCE_SPORADIC=<set_below_in_machine_variables_section>|"
    MULTI_STRING1="0,/#VARMOD#/s:#VARMOD#:PQUERY_MULTI=1\n#VARMOD#:"
    MULTI_STRING2="0,/#VARMOD#/s:#VARMOD#:FORCE_SKIPV=1\n#VARMOD#:"
    MULTI_STRING3="0,/#VARMOD#/s:#VARMOD#:FORCE_SPORADIC=1\n#VARMOD#:"
  fi
  if [ ${PXC} -eq 1 ]; then
    PXC_CLEANUP1="0,/^[ \t]*PXC_DOCKER_FIG_MOD[ \t]*=.*$/s|^[ \t]*PXC_DOCKER_FIG_MOD[ \t]*=.*$|#PXC_DOCKER_FIG_MOD=<set_below_in_machine_variables_section>|"
    PXC_CLEANUP2="0,/^[ \t]*PXC_DOCKER_FIG_LOC[ \t]*=.*$/s|^[ \t]*PXC_DOCKER_FIG_LOC[ \t]*=.*$|#PXC_DOCKER_FIG_LOC=<set_below_in_machine_variables_section>|"
    PXC_STRING1="0,/#VARMOD#/s:#VARMOD#:PXC_DOCKER_FIG_MOD=1\n#VARMOD#:"
    PXC_STRING2="0,/#VARMOD#/s:#VARMOD#:PXC_DOCKER_FIG_LOC=${SCRIPT_PWD}\/pxc-pquery\/docker-compose\/pqueryrun\/docker-compose.yml\n#VARMOD#:"
  else
    PXC_CLEANUP1="s|ZERO0|ZERO0|"  # Idem as above
    PXC_CLEANUP2="s|ZERO0|ZERO0|"
    PXC_STRING1="s|ZERO0|ZERO0|"
    PXC_STRING2="s|ZERO0|ZERO0|"
  fi
  cat ${REDUCER} \
   | sed -e "0,/^[ \t]*INPUTFILE[ \t]*=.*$/s|^[ \t]*INPUTFILE[ \t]*=.*$|#INPUTFILE=<set_below_in_machine_variables_section>|" \
   | sed -e "0,/^[ \t]*MODE[ \t]*=.*$/s|^[ \t]*MODE[ \t]*=.*$|#MODE=<set_below_in_machine_variables_section>|" \
   | sed -e "${MYEXTRA_CLEANUP}" \
   | sed -e "${TEXT_CLEANUP}" \
   | sed -e "${MULTI_CLEANUP1}" \
   | sed -e "${MULTI_CLEANUP2}" \
   | sed -e "${MULTI_CLEANUP3}" \
   | sed -e "0,/^[ \t]*MYBASE[ \t]*=.*$/s|^[ \t]*MYBASE[ \t]*=.*$|#MYBASE=<set_below_in_machine_variables_section>|" \
   | sed -e "0,/^[ \t]*PQUERY_MOD[ \t]*=.*$/s|^[ \t]*PQUERY_MOD[ \t]*=.*$|#PQUERY_MOD=<set_below_in_machine_variables_section>|" \
   | sed -e "0,/^[ \t]*PQUERY_LOC[ \t]*=.*$/s|^[ \t]*PQUERY_LOC[ \t]*=.*$|#PQUERY_LOC=<set_below_in_machine_variables_section>|" \
   | sed -e "${PXC_CLEANUP1}" \
   | sed -e "${PXC_CLEANUP2}" \
   | sed -e "0,/#VARMOD#/s:#VARMOD#:MODE=${MODE}\n#VARMOD#:" \
   | sed -e "${TEXT_STRING1}" \
   | sed -e "${TEXT_STRING2}" \
   | sed -e "0,/#VARMOD#/s:#VARMOD#:MYBASE=\"${BASE}\"\n#VARMOD#:" \
   | sed -e "0,/#VARMOD#/s:#VARMOD#:INPUTFILE=\"${INPUTFILE}\"\n#VARMOD#:" \
   | sed -e "${MYEXTRA_STRING1}" \
   | sed -e "${MULTI_STRING1}" \
   | sed -e "${MULTI_STRING2}" \
   | sed -e "${MULTI_STRING3}" \
   | sed -e "0,/#VARMOD#/s:#VARMOD#:PQUERY_MOD=1\n#VARMOD#:" \
   | sed -e "0,/#VARMOD#/s:#VARMOD#:PQUERY_LOC=${PQUERY_BIN}\n#VARMOD#:" \
   | sed -e "${PXC_STRING1}" \
   | sed -e "${PXC_STRING2}" \
   > ./reducer${OUTFILE}.sh
  chmod +x ./reducer${OUTFILE}.sh 
}

# Main pquery results processing
for SQLLOG in $(ls ./*/pquery_thread-0.sql 2>/dev/null); do
  TRIAL=`echo ${SQLLOG} | sed 's|./||;s|/.*||'`
  if [ ${NEW_MYEXTRA_METHOD} -eq 1 ]; then
    MYEXTRA=
    VALGRIND_CHECK=
    if [ -r ./${TRIAL}/MYEXTRA ]; then
      MYEXTRA=$(cat ./${TRIAL}/MYEXTRA)
    fi
    if [ -r ./${TRIAL}/VALGRIND ]; then
      VALGRIND_CHECK="TRUE"
    fi
  fi
  if [ ${PXC} -eq 1 ]; then
    for SUBDIR in `ls -lt ${TRIAL} --time-style="long-iso"  | egrep '^d'  | awk '{print $8}' | egrep -E '^[0-9]+$'`; do
      OUTFILE="${TRIAL}-${SUBDIR}"
      rm -Rf  ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing
      touch ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing
      echo "========== Processing pquery trial $TRIAL"
      if [ -r ./reducer${TRIAL}_${SUBDIR}.sh ]; then
        echo "* Reducer for this trial (./reducer${TRIAL}_${SUBDIR}.sh) already exists. Skipping to next trial."
        continue
      fi
      if [ "${MULTI}" == "1" ]; then
        INPUTFILE=${WORKD_PWD}/${TRIAL}/${TRIAL}.sql
        cp ${INPUTFILE} ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.backup
      else
        INPUTFILE=`echo ${SQLLOG} | sed "s|^[./]\+|/|;s|^|${WORKD_PWD}|"`
      fi
      BIN=`ls -1 ${WORKD_PWD}/${TRIAL}/{SUBDIR}/mysqld 2>&1 | head -n1 | grep -v "No such file"`
      if [ ! -r $BIN ]; then
        echo "Assert! mysqld binary '$BIN' could not be read"
        exit 1
      fi
      if [ `ls ./pquery-run.log 2>/dev/null | wc -l` -eq 0 ]; then
        BASE="/sda/Percona-Server-5.6.21-rel70.0-696.Linux.x86_64-debug"
      else
        BASE="`grep 'Basedir:' ./pquery-run.log | sed 's|^.*Basedir[: \t]*||;;s/|.*$//'`"
      fi
      BASE="/sda/Percona-Server-5.6.21-rel70.0-696.Linux.x86_64-debug"
      CORE=`ls -1 ./${TRIAL}/${SUBDIR}/*core* 2>&1 | head -n1 | grep -v "No such file"`
      if [ "$CORE" != "" ]; then
        extract_queries_core
      fi
      ERRLOG=./${TRIAL}/${SUBDIR}/error.log
      if [ "$ERRLOG" != "" ]; then
        extract_queries_error_log
      else
        echo "Assert! Error log at ./${TRIAL}/${SUBDIR}/error.log could not be read?"
        exit 1
      fi
      TEXT=`${SCRIPT_PWD}/text_string.sh ./${TRIAL}/${SUBDIR}/error.log`
      echo "* TEXT variable set to: \"${TEXT}\""
      if [ "${MULTI}" == "1" ]; then
         if [ -s ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing ];then
           auto_interleave_failing_sql
         fi
      fi
      generate_reducer_script
    done
  else
    OUTFILE=$TRIAL
    rm -Rf ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing
    if [ ${REACH} -eq 0 ]; then # Avoid normal output if this is an automated run (REACH=1)
      echo "========== Processing pquery trial $TRIAL"
    fi
    if [ ! -r ./${TRIAL}/start ]; then
      echo "* No ./${TRIAL}/start detected, so this was likely a SAVE_SQL=1, SAVE_TRIALS_WITH_CORE_ONLY=1 trial with no core generated. Skipping to next trial."
      continue
    fi
    if [ -r ./reducer${TRIAL}.sh ]; then
      echo "* Reducer for this trial (./reducer${TRIAL}.sh) already exists. Skipping to next trial."
      continue
    fi
    if [ "${MULTI}" == "1" ]; then
      INPUTFILE=${WORKD_PWD}/${TRIAL}/${TRIAL}.sql
      cp ${INPUTFILE} ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.backup
    else
      INPUTFILE=`echo ${SQLLOG} | sed "s|^[./]\+|/|;s|^|${WORKD_PWD}|"`
    fi
    BIN=`grep "mysqld" ./${TRIAL}/start | sed 's|mysqld .*|mysqld|;s|.* \(.*bin/mysqld\)|\1|'`
    if [ ! -r $BIN ]; then
      echo "Assert! mysqld binary '$BIN' could not be read"
      exit 1
    fi
    BASE=`echo $BIN | sed 's|/bin/mysqld||'`
    if [ ! -d $BASE ]; then
      echo "Assert! Basedir '$BASE' does not look to be a directory"
      exit 1
    fi
    CORE=`ls -1 ./${TRIAL}/data/*core* 2>&1 | head -n1 | grep -v "No such file"`
    if [ "$CORE" != "" ]; then
      extract_queries_core
    fi
    ERRLOG=./${TRIAL}/log/master.err
    if [ "$ERRLOG" != "" ]; then
      extract_queries_error_log
    else
      echo "Assert! Error log at ./${TRIAL}/log/master.err could not be read?"
      exit 1
    fi
    TEXT=`${SCRIPT_PWD}/text_string.sh ./${TRIAL}/log/master.err`
    echo "* TEXT variable set to: \"${TEXT}\""
    if [ "${MULTI}" == "1" -a -s ${WORKD_PWD}/${TRIAL}/${TRIAL}.sql.failing ];then
      auto_interleave_failing_sql
    fi
    generate_reducer_script
  fi
  if [ "${MYEXTRA}" != "" ]; then
    echo "* MYEXTRA variable set to: ${MYEXTRA}"
  fi
  if [ "${VALGRIND_CHECK}" == "TRUE" ]; then
    echo "* Valgrind was used for this trial"
  fi
done

if [ ${REACH} -eq 0 ]; then # Avoid normal output if this is an automated run (REACH=1)
  echo "======================================================================================================================================================"
  echo -e "\nDone!! Start reducer scripts like this: './reducerTRIAL.sh' where TRIAL stands for the trial number you would like to reduce"
  echo "Both reducer and the SQL trace file have been pre-prepped with all the crashing queries and settings, ready for you to use without further options!"
  echo -e "\nIMPORTANT!! Remember that settings pre-programmed into reducerTRIAL.sh by this script are in the 'Machine configurable variables' section, not"
  echo "in the 'User configurable variables' section. As such, and for example, if you want to change the settings (for example change MODE=3 to MODE=4), then"
  echo "please make such changes in the 'Machine configurable variables' section which is a bit lower in the file (search for 'Machine' to find it easily)."
  echo "Any changes you make in the 'User configurable variables' section will not take effect as the Machine sections overwrites these!"
  echo -e "\nIMPORTANT!! Remember that a number of testcases as generated by reducer.sh will require the MYEXTRA mysqld options used in the original test."
  echo "The reducer<nr>.sh scripts already have these set, but when you want to replay a testcase in some other mysqld setup, remember you will need these"
  echo "options passed to mysqld directly or in some my.cnf script. Note also, in reverse, that the presence of certain mysqld options that did not form part"
  echo "of the original test can cause the same effect; non-reproducibility of the testcase. You want a replay setup as closely matched as possible. If you"
  echo "use the new scripts (./{epoch}_init, _start, _stop, _cl, _run, _run-pquery, _stop etc. then these options for mysqld will already be preset for you."
fi

#!/bin/bash
TARGETDB="${MYSQL_DATABASE:-codebeamer}"
OUTFILE="/tmp/${TARGETDB}-paralell-connection.log"
export MYCNF=${MYCNF:-./.my.cnf}
export MAX_CONN_USE=35
export MAX_CONN_INTERVALL_CHECK="0.100"

#connection count select count(*) from INFORMATION_SCHEMA.PROCESSLIST where info like '%';
wait_until_below_sql_statements () {
  #echo "must below $MAX_CONN_USE"
  current_sql_count=100

  while [ ${current_sql_count} -gt ${MAX_CONN_USE} ]; do
  	current_sql_count=$(  echo " select count(*) from INFORMATION_SCHEMA.PROCESSLIST where info like '%';"|mysql --defaults-file=${MYCNF} -s )
  	if [ $? -ne 0 ];then
	  	echo "error....happen db dead? exeting now"
	  	exit 1
  	fi
	if [ ${current_sql_count} -gt ${MAX_CONN_USE} ]; then
		echo -n "."
		sleep ${MAX_CONN_INTERVALL_CHECK}
	fi
  done
}

wait_until_table_is_usable () {
  #echo "must below $MAX_CONN_USE"
  statement_count=10
  while [ ${statement_count} -gt 0 ]; do
  	statement_count=$(  echo "show open tables where \`Database\` like DATABASE() and \`Table\` like '$1' and in_use>0;"|mysql --defaults-file=${MYCNF} -s | wc -l )
	#echo "count $statement_count "
  	if [ $? -ne 0 ];then
	  	echo "error....happen db dead? exeting now"
	  	exit 1
  	fi
	if [  ${statement_count} -gt 0 ]; then
		echo -n "."
		sleep ${MAX_CONN_INTERVALL_CHECK}
	fi
  done

}
###############################################main###################################################

#object_reference got an field id autoincrement


#just be sure that none is using my table
wait_until_table_is_usable object_revision

MAX_OBJ_ID=`echo 'SELECT max(obj.id) FROM  object obj;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
start=0

#we rush multiple times over object_reference
echo "start multiconnection" >> ${OUTFILE}
echo "------>start-obfuscate_object_revision_multi_thread"
while [ ${start} -lt ${MAX_OBJ_ID} ];do
	let end=${start}+1000
        echo "von $start bis $end"
        echo "CALL obfuscate_object_revision_multi_thread(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
	let start=${end}+1
done
echo "------>stop-obfuscate_object_revision_multi_thread"
wait

#just be sure that none is using my table
wait_until_table_is_usable object_reference


MAX_TASK_ID=`echo 'SELECT max(tt.id) FROM  task tt;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi

start=0
#max_obj_id 	-> MAX_OBJ_ID
#max_task_id	->

# one or the other way....
if [ ${MAX_TASK_ID} -lt ${MAX_OBJ_ID} ];then
	END_COUNT=${MAX_OBJ_ID}
else
	END_COUNT=${MAX_TASK_ID}
fi
while [ ${start} -lt ${END_COUNT} ];do
	let end=${start}+1000
        echo "von $start bis $end"
	echo "CALL obfuscate_object_reference_multi_thread(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
        let start=${end}+1 
done

wait
echo "stop obfuscated_object_reference" >> ${OUTFILE}

exit 0
######################################autoincrement example
#object_reference got an field id outoincrement
OBJ_MAX_ID=`echo 'select max(id) from object_reference;'|mysql --defaults-file=${MYCNF} -s 2>&1 `
if [ $? -ne 0 ];then
        echo "error...."
        exit 2
fi
let "OBJ_MAX_ID=${OBJ_MAX_ID} + 1"
start=1
MYCHUNK=10000

while [ ${start} -lt ${OBJ_MAX_ID} ];do
	let end=${start}+${MYCHUNK}
        echo "von $start bis $end"
        echo "call myfunction(${start},${end});"|mysql --defaults-file=${MYCNF} 2>&1 >> ${OUTFILE} &
	wait_until_below_sql_statements
        let start=${end}+1 	
done

wait

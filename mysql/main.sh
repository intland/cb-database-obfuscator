#!/bin/bash
INSTDIR=`dirname $0`
cd $INSTDIR
export MYCNF=${MYCNF:-./.my.cnf}
mysql  --defaults-file=${MYCNF} < main.sql

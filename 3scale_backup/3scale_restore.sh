#!/bin/bash
#
# This is based on
#  - https://github.com/3scale/3scale-Operations/blob/master/docs/day-2-operations/Backups.adoc
# and
#  - https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.6/html/operating_3scale/backup-restore#backup_procedures
#

BACKUP_DIR=${1:-backup}

# Source our environment
source ../ocp.env
source ../functions

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

echo "Restoring a new 3scale backup from directory ${BACKUP_DIR}"

if [ ! -d ${BACKUP_DIR} ]; then
    echo "Missing Backup Directore ${BACKUP_DIR}"
    exit -1
fi

echo "Restore mySQL"
echo "  Copy the MySQL dump to the system-mysql pod:"
oc rsh $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name') bash -c 'export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}; mysqldump --single-transaction -hsystem-mysql -uroot system' | gzip > ${BACKUP_DIR}/system-mysql-backup.gz

oc cp ${BACKUP_DIR}/system-mysql-backup.gz $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq '.items[0].metadata.name' -r):/var/lib/mysql

echo "  Decompress the Backup File:"

oc rsh $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name') bash -c 'gzip -d ${HOME}/system-mysql-backup.gz'

echo "  Restore the MySQL DB Backup file:"

oc rsh $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name') bash -c 'export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}; mysql -hsystem-mysql -uroot system < ${HOME}/system-mysql-backup'



echo "Restore System App"


oc rsync ${BACKUP_DIR}/system/ $(oc get pods -l 'deploymentConfig=system-app' -o json | jq '.items[0].metadata.name' -r):/opt/system/public/system


echo "Restore zync database"

echo "  Copy the Zync Database dump to the zync-database pod:"

oc cp ${BACKUP_DIR}/zync-database-backup.gz $(oc get pods -l 'deploymentConfig=zync-database' -o json | jq '.items[0].metadata.name' -r):/var/lib/pgsql/

echo "  Decompress the Backup File:"

oc rsh $(oc get pods -l 'deploymentConfig=zync-database' -o json | jq -r '.items[0].metadata.name') bash -c 'gzip -d ${HOME}/zync-database-backup.gz'

echo "  Restore the PostgreSQL DB Backup file:"

oc rsh $(oc get pods -l 'deploymentConfig=zync-database' -o json | jq -r '.items[0].metadata.name') bash -c 'psql -f ${HOME}/zync-database-backup'


#echo "Restore backend-redis"

echo "Currently refer to documentation"
echo "https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.6/html/operating_3scale/backup-restore#backup_procedures"
exit 1

# This is a framework but I need to automate the config map changes
#
# $1 = system|backend
restore_redis ()
{

    if [ $1 != 'system' && $1 != 'backup' ]; then
	echo "restore_redis only supports the arguments" >&2
	echo "system | backup" >&2
	exit 1
    fi

    echo "Restore ${1}-redis"
    echo "Edit the redis-config configmap:"

    oc edit configmap redis-config

    echo "Comment SAVE commands in the redis-config configmap:"

     #save 900 1
     #save 300 10
     #save 60 10000

    echo "Set appendonly to no in the redis-config configmap:"

    appendonly no

    echo "Redeploy ${1}-redis to load the new configurations:"

    oc rollout latest dc/${1}-redis

    echo "Rename the dump.rb file:"

    oc rsh $(oc get pods -l 'deploymentConfig=${1}-redis' -o json | jq '.items[0].metadata.name' -r) bash -c 'mv ${HOME}/data/dump.rdb ${HOME}/data/dump.rdb-old'

    echo "Rename the appendonly.aof file:"

    oc rsh $(oc get pods -l 'deploymentConfig=${1}-redis' -o json | jq '.items[0].metadata.name' -r) bash -c 'mv ${HOME}/data/appendonly.aof ${HOME}/data/appendonly.aof-old'

    echo "Move the Backup file to the POD:"

    oc cp ./${1}-redis-dump.rdb $(oc get pods -l 'deploymentConfig=${1}-redis' -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb

    echo "Redeploy ${1}-redis to load the backup:"

    oc rollout latest dc/${1}-redis

    echo "Edit the redis-config configmap:"

    oc edit configmap redis-config

    echo "Uncomment SAVE commands in the redis-config configmap:"

     save 900 1
     save 300 10
     save 60 10000

    echo "Set appendonly to yes in the redis-config configmap:"

    appendonly yes

    echo "Redeploy ${1}-redis to reload the default configurations:"

    oc rollout latest dc/${1}-redis
}

restore_redis backend
restore_redis system


#!/bin/bash
#
# This is based on
#  - https://github.com/3scale/3scale-Operations/blob/master/docs/day-2-operations/Backups.adoc
# and
#  - https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.6/html/operating_3scale/backup-restore#backup_procedures
#
# [1] = backup directory
# [2] = OCP namespace/project for 3scale


BACKUP_DIR=${1:-backup}

# Source our environment
source ../ocp.env
source ../functions
source ../3scale.env

OCP_NAMESPACE=${2:-$API_MANAGER_NS}

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

if ( ! projectExists ${OCP_NAMESPACE}); then
    printERROR "No 3scale service deployed under ${OCP_NAMESPACE} - ${1} Exiting"
    exit -1
fi  

if [ ! -d ${BACKUP_DIR} ]; then
    printError "Missing Backup Directore ${BACKUP_DIR}"
    exit -1
fi

if [ ! -f ${BACKUP_DIR}/backup.env ]; then
    printError "Invalid backup in ${BACKUP_DIR} - missing backup.env"
    exit -1
fi

source ${BACKUP_DIR}/backup.env

oc project ${OCP_NAMESPACE}

printInfo "Restoring a new 3scale backup from directory ${BACKUP_DIR} into project ${OCP_NAMESPACE}"

# rewrite_db_backup 
#
# arg1 - src file
# arg2 - dest file
#
# We need the second sed line due to wierd data in the mysql backup
#
rewrite_db_backup ()
{
   
    if [ ! -f ${1} ]; then
        printError "Missing database file ${1} for rewrite"
        exit -1
    fi

    printInfo "  Re-write the cluster information for database ${1}"
    printInfo "  into file ${2}"
    printInfo "  modify ${OLD_NAMESPACE} to ${OCP_NAMESPACE}"
    printInfo "   and ${OLD_DOMAIN} to ${OCP_DOMAIN}" 
    gunzip -c ${1} | \
    sed "s/${OLD_NAMESPACE}/${OCP_NAMESPACE}/g;s/${OLD_DOMAIN}/${OCP_DOMAIN}/g" | \
    sed "s/\^\[\[Z-/-/g" | \
    gzip -c - > ${2}
}


restore_system_mysql ()
{
MYSQL_POD=$(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name')
printInfo "Restore mySQL to ${MYSQL_POD}"

printInfo "  Re-write the cluster information:"
rewrite_db_backup ${BACKUP_DIR}/system-mysql-backup.gz ${BACKUP_DIR}/system-mysql-restore.gz

printInfo "  Make sure we've got no old backups on the pod"
oc rsh ${MYSQL_POD} bash -c 'rm -f /var/lib/mysql/system-mysql-restore'

printInfo "  Copy the MySQL dump to the system-mysql pod:"
oc cp ${BACKUP_DIR}/system-mysql-restore.gz ${MYSQL_POD}:/var/lib/mysql

printInfo "  Decompress the Backup File:"

oc rsh ${MYSQL_POD} bash -c 'gzip -d ${HOME}/system-mysql-restore.gz'

printInfo "  Restore the MySQL DB Backup file:"

oc rsh ${MYSQL_POD} bash -c 'export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}; mysql -hsystem-mysql -uroot system < ${HOME}/system-mysql-restore'
printInfo "mySQL restore to ${MYSQL_POD} completed"
}



restore_system_app ()
{
printInfo "Restore System App"
printWarning "Currently we might get an error that the destination directory is missing"

oc rsync ${BACKUP_DIR}/system/ $(oc get pods -l 'deploymentConfig=system-app' -o json | jq '.items[0].metadata.name' -r):/opt/system/public/system
}


restore_zync_database ()
{
printInfo "Restore zync database"
PSQL_POD=$(oc get pods -l 'deploymentConfig=zync-database' -o json | jq -r '.items[0].metadata.name')

printInfo "Scale down zync and zyncq-que ahead of restore"
oc scale --replicas=0  dc zync
oc scale --replicas=0  dc zync-que

printInfo "  Re-write the cluster information:"
rewrite_db_backup ${BACKUP_DIR}/zync-database-backup.gz ${BACKUP_DIR}/zync-database-restore.gz

printInfo "  Make sure we've got no old backups on the pod"
oc rsh ${PSQL_POD} bash -c 'rm -f ${HOME}/zync-database-restore*'

printInfo "  Copy the Zync Database dump to the zync-database pod ${PSQL_POD}:"
oc cp ${BACKUP_DIR}/zync-database-restore.gz ${PSQL_POD}:/var/lib/pgsql/

printInfo "  Decompress the Backup File:"
oc rsh ${PSQL_POD} bash -c 'gzip -d ${HOME}/zync-database-restore.gz'

printInfo "  Check we've scaled down ahead of restore"
oc get dc -l threescale_component=zync

printInfo "  Restore the PostgreSQL DB Backup file:"
oc rsh ${PSQL_POD} bash -c 'psql -f ${HOME}/zync-database-restore'

printInfo "Scale up zync and zyncq-que now the database is restored"
oc scale --replicas=1  dc zync
oc scale --replicas=1  dc zync-que

printInfo "  Confirm we've scaled the zync pods back up"
sleep 2s
oc get dc -l threescale_component=zync

printInfo "zync database restore to ${PSQL_POD} completed"
}



#printInfo "Currently refer to documentation"
#echo "https://access.redhat.com/documentation/en-us/red_hat_3scale_api_management/2.6/html/operating_3scale/backup-restore#backup_procedures"
#exit 1


# Basically We need a way to patch the config map

# This is a framework but I need a more elegant way to modify the config map
# and make sure the deployments have completed before moving on
# 
# Note that the redis container will get re-deployed during the process
# and the assiciated pod name will change
#
# $1 = system|backend
restore_redis ()
{

    if [ "${1}" != "system" ] && [ "${1}" != "backend" ]; then
	printError "restore_redis only supports the arguments" >&2
	printError "system | backend" >&2
	exit 1
    fi

    printInfo "Restore ${1}-redis"
    printInfo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    printInfo "Modify the redis-config configmap:"

    oc get --export configmap redis-config -o yaml > redis-config.orig.yaml
    cat redis-config.orig.yaml | sed "s/ save / #save /g;s/ appendonly yes/ appendonly no/" > redis-config.new.yaml
    oc apply -f redis-config.new.yaml

    printInfo "Redeploy ${1}-redis to load the new configurations:"

    oc rollout latest dc/${1}-redis

    printInfo "Sleep 30s while the rollout actions"
    sleep 30s
    ##oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    printInfo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    printInfo "Sleep 10s while the container stabilises"
    sleep 10s
    printInfo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r

    REDIS_POD=$(oc get pods -l "deploymentConfig=${1}-redis" -o json | jq -r '.items[0].metadata.name')
    printInfo "Rename the dump.rb file on ${REDIS_POD}:"

    oc rsh ${REDIS_POD} bash -c 'mv ${HOME}/data/dump.rdb ${HOME}/data/dump.rdb-old'

    printInfo "Rename the appendonly.aof file:"

    oc rsh ${REDIS_POD} bash -c 'mv ${HOME}/data/appendonly.aof ${HOME}/data/appendonly.aof-old'

    printInfo "Move the Backup file to the POD:"

    oc cp ${BACKUP_DIR}/${1}-redis-dump.rdb ${REDIS_POD}:/var/lib/redis/data/dump.rdb

    printInfo "Redeploy ${1}-redis to load the backup:"

    oc rollout latest dc/${1}-redis

    printInfo "Sleep 30s while the rollout actions"
    sleep 30s
    ##oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    printInfo "Modify the redis-config configmap back to its original settings:"
    oc apply -f redis-config.orig.yaml

    printInfo "Redeploy ${1}-redis to reload the default configurations:"

    oc rollout latest dc/${1}-redis
    printInfo "Sleep 30s while the rollout actions"
    sleep 30s
    ##oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    printInfo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    printInfo "Sleep 10s while the container stabilises"
    sleep 10s
    printInfo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
}

restore_system_mysql
restore_zync_database
restore_system_app

printInfo "Restore backend-redis"
restore_redis backend
restore_redis system


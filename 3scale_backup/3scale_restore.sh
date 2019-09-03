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


# Basically We need a way to patch the config map

# This is a framework but I need a more elegant way to modify the config map
# and make sure the deployments have completed before moving on
#
# $1 = system|backend
restore_redis ()
{

    if [ "${1}" != "system" ] && [ "${1}" != "backend" ]; then
	echo "restore_redis only supports the arguments" >&2
	echo "system | backend" >&2
	exit 1
    fi

    echo "Restore ${1}-redis"
    echo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    echo "Modify the redis-config configmap:"

    oc get --export configmap redis-config -o yaml > redis-config.orig.yaml
    cat redis-config.orig.yaml | sed "s/ save / #save /g;s/ appendonly yes/ appendonly no/" > redis-config.new.yaml
    oc apply -f redis-config.new.yaml

    echo "Redeploy ${1}-redis to load the new configurations:"

    oc rollout latest dc/${1}-redis

    echo "Sleep 20s while the rollout actions"
    sleep 20s
    oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    echo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    echo "Sleep 10s while the container stabilises"
    sleep 10s
    echo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r

    echo "Rename the dump.rb file:"

    oc rsh $(oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r) bash -c 'mv ${HOME}/data/dump.rdb ${HOME}/data/dump.rdb-old'

    echo "Rename the appendonly.aof file:"

    oc rsh $(oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r) bash -c 'mv ${HOME}/data/appendonly.aof ${HOME}/data/appendonly.aof-old'

    echo "Move the Backup file to the POD:"

    oc cp ./${1}-redis-dump.rdb $(oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb

    echo "Redeploy ${1}-redis to load the backup:"

    oc rollout latest dc/${1}-redis

    echo "Sleep 20s while the rollout actions"
    sleep 20s
    oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    echo "Modify the redis-config configmap back to its original settings:"
    oc apply -f redis-config.orig.yaml

    echo "Redeploy ${1}-redis to reload the default configurations:"

    oc rollout latest dc/${1}-redis
    echo "Sleep 20s while the rollout actions"
    sleep 20s
    oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
    oc_wait_for  pod ${1}-redis deploymentconfig ${API_MANAGER_NS}

    echo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
    echo "Sleep 10s while the container stabilises"
    sleep 10s
    echo "Current ${1}-redis pods"
    oc get pods -l "deploymentConfig=${1}-redis" -o json | jq '.items[0].metadata.name' -r
}

restore_redis backend
restore_redis system


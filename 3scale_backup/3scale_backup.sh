#!/bin/bash
#
# This is based on https://github.com/3scale/3scale-Operations/blob/master/docs/day-2-operations/Backups.adoc
#

# Source our environment
source ../ocp.env
source ../functions
source ../3scale.env


if [ "${1}missing" == "missing" ]; then
    echo "Usage: $1 <backup_dir> [optional 3scale namespace]" >&2
    exit 1
fi

BACKUP_DIR=${1}
OCP_NAMESPACE=${2:-$API_MANAGER_NS}

# And login as the kubeadmin user
oc_login

if ( ! projectExists ${OCP_NAMESPACE}); then
    printERROR "No 3scale service deployed under ${OCP_NAMESPACE} - ${1} Exiting"
    exit -1
fi  

oc project ${OCP_NAMESPACE}

printInfo "Creating a new 3scale backup into directory ${BACKUP_DIR}"

if [ ! -d ${BACKUP_DIR} ]; then
    mkdir -p ${BACKUP_DIR}
fi

printInfo "Making sure key environment settings are captured about the backup environent into ${BACKUP_DIR}"
printInfo "# Environment settings needed to re-write 3scale on recovery" > ${BACKUP_DIR}/backup.env
printInfo "OLD_NAMESPACE=${OCP_NAMESPACE}" >> ${BACKUP_DIR}/backup.env
printInfo "OLD_DOMAIN=${OCP_DOMAIN}" >> ${BACKUP_DIR}/backup.env

printInfo "Backup mySQL"
oc rsh $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name') bash -c 'export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}; mysqldump --single-transaction -hsystem-mysql -uroot system' | gzip > ${BACKUP_DIR}/system-mysql-backup.gz


printInfo "Backup System App"
printWarning "Warning - we're currently getting an error on /opt/system/public/system"
mkdir -p ${BACKUP_DIR}/system
oc rsync $(oc get pods -l 'deploymentConfig=system-app' -o json | jq '.items[0].metadata.name' -r):/opt/system/public/system ${BACKUP_DIR}/system/

printInfo "Backup zync database"
oc rsh $(oc get pods -l 'deploymentConfig=zync-database' -o json | jq '.items[0].metadata.name' -r) bash -c 'pg_dumpall -c --if-exists' | gzip > ${BACKUP_DIR}/zync-database-backup.gz

printInfo "Backup backend-redis"

oc cp $(oc get pods -l 'deploymentConfig=backend-redis' -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb ${BACKUP_DIR}/backend-redis-dump.rdb

printInfo "Backup system-redis"

oc cp $(oc get pods -l 'deploymentConfig=system-redis' -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb ${BACKUP_DIR}/system-redis-dump.rdb



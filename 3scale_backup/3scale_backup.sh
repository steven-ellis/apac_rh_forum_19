#!/bin/bash
#
# This is based on https://github.com/3scale/3scale-Operations/blob/master/docs/day-2-operations/Backups.adoc
#

BACKUP_DIR=${1:-backup}

# Source our environment
source ../ocp.env
source ../functions
source ../3scale.env

OCP_NAMESPACE=${2:-$API_MANAGER_NS}

# And login as the kubeadmin user
oc_login

oc project ${OCP_NAMESPACE}

echo "Creating a new 3scale backup into directory ${BACKUP_DIR}"

if [ ! -d ${BACKUP_DIR} ]; then
    mkdir -p ${BACKUP_DIR}
fi

echo "Making sure key environment settings are captured about the backup environent into ${BACKUP_DIR}"
echo "# Environment settings needed to re-write 3scale on recovery" > ${BACKUP_DIR}/backup.env
echo "OLD_NAMESPACE=${OCP_NAMESPACE}" >> ${BACKUP_DIR}/backup.env
echo "OLD_DOMAIN=${OCP_DOMAIN}" >> ${BACKUP_DIR}/backup.env

echo "Backup mySQL"
oc rsh $(oc get pods -l 'deploymentConfig=system-mysql' -o json | jq -r '.items[0].metadata.name') bash -c 'export MYSQL_PWD=${MYSQL_ROOT_PASSWORD}; mysqldump --single-transaction -hsystem-mysql -uroot system' | gzip > ${BACKUP_DIR}/system-mysql-backup.gz


echo "Backup System App"
echo "Warning - we're currently getting an error on /opt/system/public/system"
mkdir -p ${BACKUP_DIR}/system
oc rsync $(oc get pods -l 'deploymentConfig=system-app' -o json | jq '.items[0].metadata.name' -r):/opt/system/public/system ${BACKUP_DIR}/system/

echo "Backup zync database"
oc rsh $(oc get pods -l 'deploymentConfig=zync-database' -o json | jq '.items[0].metadata.name' -r) bash -c 'pg_dumpall -c --if-exists' | gzip > ${BACKUP_DIR}/zync-database-backup.gz

echo "Backup backend-redis"

oc cp $(oc get pods -l 'deploymentConfig=backend-redis' -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb ${BACKUP_DIR}/backend-redis-dump.rdb

echo "Backup system-redis"

oc cp $(oc get pods -l 'deploymentConfig=system-redis' -o json | jq '.items[0].metadata.name' -r):/var/lib/redis/data/dump.rdb ${BACKUP_DIR}/system-redis-dump.rdb



#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# Step 1 - 3scale specific settings
source ./3scale.env

# And login as the kubeadmin user

oc_login

OCP_NAMESPACE=$API_MANAGER_NS

# Need a way to make sure pods are running before we continue
#
# $1 = app-name
#
# EG
#    confirm_pods_running rook-ceph-mon
#
confirm_pods_running ()
{

   for i in {1..12}
   do
      echo "checking status of pod $1 attempt $i"
      status=` oc get pods -o json --selector=app=${1} -n ${OCP_NAMESPACE} |\
               jq ".items[].status.phase" | uniq`
      if [ ${status} == '"Running"' ] ; then
         return;
      fi
      sleep 10s
   done
   echo "Pod $1 not in Running state" >&2
   exit
}


# Step2: A Cluster Admin of a production OpenShift environment typically applies clusterquotas and limitranges.
# NOTE Not needed for our Demo Environment

#oc create clusterquota clusterquota-$OCP_AMP_ADMIN_ID \
#  --project-annotation-selector=openshift.io/requester=$OCP_AMP_ADMIN_ID \
#  --hard requests.cpu="4" \
#  --hard limits.cpu="8" \
#  --hard requests.memory="16Gi" \
#  --hard limits.memory="24Gi" \
#  --hard configmaps="15" \
#  --hard pods="30" \
#  --hard persistentvolumeclaims="10" \
#  --hard services="150" \
#  --hard secrets="150" \
#  --hard requests.storage="40Gi" 


# Step 3: Switch to the cluster admin OCP user and set a cluster quota on the user: $OCP_USERNAME 
# NOTE Not needed for our Demo Environment

#oc create clusterquota clusterquota-$OCP_USERNAME \
#        --project-annotation-selector=openshift.io/requester=$OCP_USERNAME \
#        --hard requests.cpu="1" \
#        --hard limits.cpu="2"  \
#        --hard requests.memory="4Gi" \
#        --hard limits.memory="8Gi" \
#        --hard configmaps="5" \
#        --hard pods="10" \
#        --hard persistentvolumeclaims="3"  \
#        --hard services="30" \
#        --hard secrets="30" \
#        --hard requests.storage="10Gi" 

#echo 'Expected Output: clusterresourcequota "clusterquota-opentlc-mgr" created'

# Step 4: Create Limit Range for 3scale Resources
#         and create the project

oc new-project ${API_MANAGER_NS}

echo "
apiVersion: v1
kind: LimitRange
metadata:
  name: ${API_MANAGER_NS}-core-resource-limits
spec:
  limits:
  - default:
      cpu: 250m
      memory: 128Mi
    defaultRequest:
      cpu: 50m
      memory: 64Mi
    max:
      memory: 6Gi
    min:
      memory: 10Mi
    type: Container
  - max:
      memory: 12Gi
    min:
      memory: 6Mi
    type: Pod
"| oc create -n $API_MANAGER_NS -f -

# Step 5: Annotate the API Manager project such that its resources are managed by a cluster quota


oc annotate namespace $API_MANAGER_NS openshift.io/requester=$OCP_AMP_ADMIN_ID --overwrite --as=system:admin

# Step 6: Provide the user, $OCP_USERNAME, with view access to this namespace


oc adm policy add-role-to-user view $OCP_USERNAME -n $API_MANAGER_NS --as=system:admin


# Step 7: Install 3scale setup using the template amps3.yml.

oc new-app \
  -f ./amps3.yml \
  -p "MASTER_NAME=$API_MASTER_NAME" \
  -p "MASTER_PASSWORD=$API_MASTER_PASSWORD" \
  -p "ADMIN_PASSWORD=$API_TENANT_PASSWD" \
  -p "ADMIN_ACCESS_TOKEN=$API_TENANT_ACCESS_TOKEN" \
  -p "TENANT_NAME=$TENANT_NAME" \
  -p "WILDCARD_DOMAIN=$OCP_WILDCARD_DOMAIN" \
  -p "WILDCARD_POLICY=Subdomain" \
  -n $API_MANAGER_NS \
  --as=system:admin | tee ./3scale_amp_provision_details.txt


echo 'You should see  - deploymentconfig "zync-database" created
--> Success'
sleep 10s


# Check on the deployment
oc status -n $API_MANAGER_NS

# Step 8:Resume the database tier deployments: 

#
for x in backend-redis system-memcache system-mysql system-redis zync-database; do
    echo Resuming dc:  $x
    sleep 2
    oc rollout resume dc $x -n $API_MANAGER_NS --as=system:admin
done


# check our pods are running
oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
#oc_wait_for  pod zync-database name ${API_MANAGER_NS}

#watch "echo 'wait for all pods to be running'; oc get pods -n $API_MANAGER_NS --as=system:admin|grep Running|grep -v -i deploy"

# Step 9:Resume backend listener and worker deployments:
 
for x in backend-listener backend-worker; do
   echo Resuming dc:  $x
   sleep 2
   oc rollout resume dc $x -n $API_MANAGER_NS --as=system:admin
done


# Step 10: Resume the system-app and its two containers

oc rollout resume dc system-app -n $API_MANAGER_NS --as=system:admin

# Confirm pods are running
# Could automate this one
sleep 30s
oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
sleep 10s
watch "echo 'Look for running system-app'; oc get pods -n $API_MANAGER_NS | grep system-app|grep Running| grep -v -i deploy"

# This should be the preferred approach
#confirm_pods_running system-app
oc_wait_for  pod system-app deploymentconfig ${API_MANAGER_NS}

# Make sure the other pods are all running
oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}

# Look at logs
echo "Wait 10 seconds and then look at the logs"
sleep 10s
oc logs $(oc get pod -l app=3scale-api-management | grep system-app | grep Running | awk '{print $1}')  -c system-developer | tail -200


# Step 11: Resume additional system and backend application utilities.

for x in system-sidekiq backend-cron system-sphinx; do
  echo Resuming dc:  $x
  sleep 2
  oc rollout resume dc $x -n $API_MANAGER_NS --as=system:admin
done


# Step 12: Resume API gateway deployments: 

for x in apicast-staging apicast-production; do
  echo Resuming dc:  $x
  sleep 2
  oc rollout resume dc $x -n $API_MANAGER_NS --as=system:admin
done


# Step 13: Resume remaining deployments:

for x in apicast-wildcard-router zync; do
  echo Resuming dc:  $x
  sleep 2
  oc rollout resume dc $x -n $API_MANAGER_NS --as=system:admin
done

# Step 14: Verify the state of the 3scale pods:
sleep 30s
oc_wait_for  pod 3scale-api-management app ${API_MANAGER_NS}
#watch "echo 'Confirm state of 3scale pods'; oc get pods -n $API_MANAGER_NS --as=system:admin | grep Running | grep -v -i deploy"

# Step 15: Accessing the Admin console:

echo "Two admin consoles are available with 3scale. One is the Master admin console which is used to manage the tenants. The second admin console is the Tenant Admin console which is used to manage the APIs and audiences.

Execute the below commands to get the URL of the master and tenant admin consoles.

Master Admin console: "

echo -en "\nhttps://`oc get route system-master -n $API_MANAGER_NS --template "{{.spec.host}}"` \n\n"

echo "Credentials: master/master

Tenant Admin Console:"

echo -en "\nhttps://`oc get route system-provider-admin -n $API_MANAGER_NS --template "{{.spec.host}}"` \n\n"

echo "Credentials: admin/admin"



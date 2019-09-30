#!/bin/bash
#
# Deploy a 3scale-toolbox pod
#
# https://access.redhat.com/containers/?tab=images#/registry.access.redhat.com/3scale-amp26/toolbox
# https://developers.redhat.com/blog/2019/07/29/3scale-toolbox-deploy-an-api-from-the-cli/
#
#
# Note that test requires the 3scale package to be installed locally from
#  - https://github.com/3scale/3scale_toolbox_packaging/releases/tag/v0.12.4
# 
# Community docs on the toolbox are
#  - https://github.com/3scale/3scale_toolbox
#

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# Step 1 - 3scale specific settings
source ./3scale.env

# We only login as the kubeadmin user if we've got a valid command line

OCP_NAMESPACE=3scale-toolbox

deploy_3scale_toolbox ()
{
    oc new-project ${OCP_NAMESPACE}
      
    # first we require a secrety to get access to the container
    oc create secret docker-registry threescale-registry-auth --docker-server=registry.redhat.io --docker-username=$rht_service_token_user --docker-password=$rht_service_token_password -n ${OCP_NAMESPACE} --as=system:admin

oc apply -f - <<EOF  
apiVersion: v1
kind: Pod
metadata:
  name: 3scale-toolbox
  namespace: ${OCP_NAMESPACE}
  spec:
    containers:
      - name: web
        image: registry.redhat.io/3scale-amp26/toolbox

    imagePullSecrets:
      - name: threescale-registry-auth
EOF

    oc import-image 3scale-amp26/toolbox --from=registry.redhat.io/3scale-amp26/toolbox --confirm


# Step 7: Install 3scale setup using the template amps3.yml.

	#oc new-app \
	#-f ./amps3.yml \
	#-p "MASTER_NAME=$API_MASTER_NAME" \
	#-p "MASTER_PASSWORD=$API_MASTER_PASSWORD" \
	#-p "MASTER_ACCESS_TOKEN=$API_MASTER_ACCESS_TOKEN" \
	#-p "ADMIN_PASSWORD=$API_TENANT_PASSWD" \
	#-p "ADMIN_ACCESS_TOKEN=$API_TENANT_ACCESS_TOKEN" \
	#-p "TENANT_NAME=$TENANT_NAME" \
	#-p "WILDCARD_DOMAIN=$OCP_WILDCARD_DOMAIN" \
	#-n $API_MANAGER_NS \
	#--as=system:admin | tee ./3scale_amp_provision_details.txt


}

3scale_toolbox_status ()
{
	printInfo "3scale Toolbox deployed into namespace ${OCP_NAMESPACE}"

# Step 15: Accessing the Admin console:

	echo "Two admin consoles are available with 3scale. One is the Master admin console which is used to manage the tenants. The second admin console is the Tenant Admin console which is used to manage the APIs and audiences.

Execute the below commands to get the URL of the master and tenant admin consoles."

        #echo ""
        #echo "Master Admin console: "
	#echo "    https://`oc get route -n $API_MANAGER_NS | grep "^zync-3scale-master" | awk '{print $2}'` "
	#echo "    Credentials: master/master"
        #echo ""
	#echo "Tenant Admin Console:"
	#echo "    https://`oc get route $API_TENANT_USERNAME-system-provider-admin -n $API_MANAGER_NS --template "{{.spec.host}}"`"
	#echo "    Credentials: admin/redhatdemo"
        #echo ""
	#echo "Developer Portal:"
	#echo "    https://`oc get route $API_TENANT_USERNAME-system-developer -n $API_MANAGER_NS --template "{{.spec.host}}"`"
}

# Connect to a 3scale instance and check its configuration
#
3scale_toolbox_test ()
{
     
    # login
    3scale -k  remote add  my3scale ${THREESCALE_PORTAL_ENDPOINT}

    3scale -k service list my3scale

    3scale -k application-plan list my3scale bigpharm_drug_api

    #3scale -k application-plan export -f bigpharm_basic.yaml my3scale bigpharm_drug_api bigpharm/basic

    # Need to check account data?
    #3scale -k account find my3scale

    3scale -k application list my3scale
    3scale -k application show my3scale BigPharmDrugsAp

    3scale -k activedocs list my3scale
    # BigPharmDrugsSpec

    # Integration
    3scale -k integration list my3scale

}

3scale_toolbox_export ()
{
    mkdir -p 3scale_export
    3scale -k application-plan export -f 3scale_export/bigpharm_basic.yaml my3scale bigpharm_drug_api bigpharm/basic

}

3scale_toolbox_create ()
{

    # Create the service
    3scale -k service create my3scale bigpharm_drug_api
    

}

cleanup_3scale_toolbox ()
{
#  This has a simple cleanup
	echo "Deleting the project ${OCP_NAMESPACE}"
	echo "This might take a couple of minutes to return"

	oc delete project ${OCP_NAMESPACE}
}

case "$1" in
  setup)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
	    printWarning "Service 3scale toolbox already deployed in ${OCP_NAMESPACE} - Exiting"
        else
            deploy_3scale_toolbox
            3scale_toolbox_status
        fi
        ;;
  status)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            3scale_toolbox_status
        fi
        ;;
  test)
        oc_login
        3scale_toolbox_test
        ;;
  delete|cleanup|remove)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            cleanup_3scale_toolbox
        fi
        ;;
  *)
	echo "Usage: $1 {setup|status|delete|test}" >&2
	echo " test - Connect using the 3scale tool and run some test queries" >&2
        exit 1
        ;;
esac


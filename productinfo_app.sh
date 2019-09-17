#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# And login late as the kubeadmin user
# oc_login

confirm_app_running ()
{

   for i in {1..12}
   do
      printInfo "checking for 200 status on booking app $1 attempt $i"
      GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
      CHECK_URL="http://${GATEWAY_URL}/productpage"
      status=`curl -o /dev/null -s -w "%{http_code}\n" ${CHECK_URL}`
      if [ "${status}" == "200" ] ; then
         printInfo "Application now available at at ${CHECK_URL}" >&2
         return;
      fi
      sleep 5s
   done
   printError "ERROR: Application at ${CHECK_URL} not in Running state" >&2
   exit
}

cleanup_app ()
{
    #  This has a simple cleanup
    printInfo "Deleting the project productinfo"
    printWarning "This might take a couple of minutes to return"
    oc delete project productinfo
}

deploy_app ()
{
oc new-project productinfo

oc adm policy add-scc-to-user anyuid -z default -n productinfo

oc adm policy add-scc-to-user privileged -z default -n productinfo

oc -n productinfo apply -f https://raw.githubusercontent.com/jumperwire/productinfo/master/productinfo.yaml

oc -n productinfo apply -f https://raw.githubusercontent.com/jumperwire/productinfo/master/productinfo-gateway.yaml

oc -n productinfo apply -f https://raw.githubusercontent.com/jumperwire/productinfo/master/destination-rule.yaml

oc -n productinfo apply -f https://raw.githubusercontent.com/jumperwire/productinfo/master/virtual-service-all-v1.yaml

# confirm Productinfo is running
confirm_app_running 
#export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
# you should get 200 as a response.
#curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage
}

case "$1" in
  setup)
	oc_login
        if projectExists productinfo; then
	    printWarning "Application productinfo already deployed - Exiting"
        else
	    deploy_app
        fi
	;;
  delete|cleanup|remove)
	oc_login
        if projectExists productinfo; then
	    cleanup_app
        fi
	;;
  *)
	echo "Usage: $1 {setup|delete|cleanup|remove}" >&2
	exit 1
	;;
esac



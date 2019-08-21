#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

confirm_app_running ()
{

   for i in {1..12}
   do
      echo "checking for 200 status on booking app $1 attempt $i"
      GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
      CHECK_URL="http://${GATEWAY_URL}/productpage"
      status=`curl -o /dev/null -s -w "%{http_code}\n" ${CHECK_URL}`
      if [ "${status}" == "200" ] ; then
         echo "Application now available at at ${CHECK_URL}" >&2
         return;
      fi
      sleep 5s
   done
   echo "ERROR: Application at ${CHECK_URL} not in Running state" >&2
   exit
}


oc new-project bookinfo

oc adm policy add-scc-to-user anyuid -z default -n bookinfo

oc adm policy add-scc-to-user privileged -z default -n bookinfo

oc -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/maistra-0.12/bookinfo.yaml

oc -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/maistra-0.12/bookinfo-gateway.yaml

# confirm Bookinfo is running
confirm_app_running 
#export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')
# you should get 200 as a response.
#curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage


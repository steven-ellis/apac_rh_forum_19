#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env

# And login as the kubeadmin user

oc login -u ${OCP__USER} -p ${OCP__PASS} ${OCP__ENDPOINT} --insecure-skip-tls-verify=false


oc new-project bookinfo

oc adm policy add-scc-to-user anyuid -z default -n bookinfo

oc adm policy add-scc-to-user privileged -z default -n bookinfo

oc -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/maistra-0.12/bookinfo.yaml

oc -n bookinfo apply -f https://raw.githubusercontent.com/Maistra/bookinfo/maistra-0.12/bookinfo-gateway.yaml

# confirm Bookinfo is running

export GATEWAY_URL=$(oc -n istio-system get route istio-ingressgateway -o jsonpath='{.spec.host}')

# you should get 200 as a response.

curl -o /dev/null -s -w "%{http_code}\n" http://${GATEWAY_URL}/productpage


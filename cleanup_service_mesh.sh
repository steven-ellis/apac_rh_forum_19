#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

# Remove the Operatgor istio-system
oc delete -n istio-system -f https://raw.githubusercontent.com/redhat-developer-demos/guru-night/master/config/basic-install.yaml
oc delete project istio-system

# Remove Service Mesh

oc delete -n istio-operator -f https://raw.githubusercontent.com/Maistra/istio-operator/maistra-0.11/deploy/maistra-operator.yaml
oc delete project istio-operator

# Confirm they are gone
echo "Confirm istio has been removed"
echo "Should return 'No resources found.'"
oc get pods -n istio-system
oc get pods -n istio-operator


#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env

# And login as the kubeadmin user

oc login -u ${OCP__USER} -p ${OCP__PASS} ${OCP__ENDPOINT} --insecure-skip-tls-verify=false

#!/bin/bash 

oc delete clusterresourcequotas.quota.openshift.io clusterquota-opentlc-mgr

# Install Service Mesh

oc new-project istio-operator

oc apply -n istio-operator -f https://raw.githubusercontent.com/Maistra/istio-operator/maistra-0.11/deploy/maistra-operator.yaml

# verify deployment to see if the pods are created

watch oc get pods -n istio-operator -l name=istio-operator -w

# deploy control plane

oc new-project istio-system

#oc apply -n istio-system -f config/basic-install.yaml
oc apply -n istio-system -f https://raw.githubusercontent.com/redhat-developer-demos/guru-night/master/config/basic-install.yaml


# Wait for all the Istio Pods to be available, estimated ~10 mins.

watch oc -n istio-system get pods -w


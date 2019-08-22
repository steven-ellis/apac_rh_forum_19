#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

# a pre-cleanup
echo "Depending on the OCS Lab you're using this might raise errors you can ignore"
oc delete clusterresourcequotas.quota.openshift.io clusterquota-opentlc-mgr

# Install Service Mesh

oc new-project istio-operator

oc apply -n istio-operator -f https://raw.githubusercontent.com/Maistra/istio-operator/maistra-0.11/deploy/maistra-operator.yaml

# verify deployment to see if the pods are created

#watch "echo 'Wait for Istio pods to be Running';oc get pods -n istio-operator -l name=istio-operator"
sleep 5s;
oc_wait_for  pod istio-operator name istio-operator

# deploy control plane

oc new-project istio-system

#oc apply -n istio-system -f config/basic-install.yaml
oc apply -n istio-system -f https://raw.githubusercontent.com/redhat-developer-demos/guru-night/master/config/basic-install.yaml

# We need to make sure some of the later pods are running
# We could user something like this
##- name: wait for istio sidecar-injector to initialize
## shell: "oc get deployment istio-sidecar-injector -o jsonpath='{.status.availableReplicas}' -n istio-system"
## register: sidecar_injector_replicas
## until: sidecar_injector_replicas.stdout == "1"
## retries: "30"
## delay: "3
# from
# agnosticd/ansible/roles/ocp-workload-istio-prometheus-demo/tasks/workload.yml

# Make sure some of the base istio pods are active# Make sure some of the base istio pods are active
sleep 5s;
oc_wait_for  pod istio release istio-system

echo "Going to wait a minute for other Istio pods to start"
sleep 60s;
oc_wait_for  pod istio release istio-system

# Wait for all the Istio Pods to be available, estimated ~10 mins.
watch "echo 'Wait for the Isto System pods to be running'; oc -n istio-system get pods"


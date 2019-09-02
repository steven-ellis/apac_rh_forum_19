#!/bin/bash
#
# Setup our existing environment login and confirm we have access
# 
# Also Git clone the settings for deploying the storage

source ocp.env

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

oc get clusterversion
oc get nodes
oc get whoami

# Clone the git repo for the storage test drive if it isn't already present
if [ ! -d "content" ]; then
    #git clone https://github.com/openshift/openshift-cns-testdrive.git -b ocp4-prod content
    git clone git@github.com:openshift/openshift-cns-testdrive.git -b ocp4-prod content
fi


# Clone the git repo for rook
if [ ! -d "rook.master" ]; then
    #git clone https://github.com/openshift/openshift-cns-testdrive.git -b ocp4-prod content
    git clone git@github.com:rook/rook.git -b master rook.master
fi

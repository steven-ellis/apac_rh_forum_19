#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env

# And login as the kubeadmin user

oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

#  This has a simple cleanup
echo "Deleting the project bookinfo"
echo "This might take a couple of minutes to return"
oc delete project bookinfo

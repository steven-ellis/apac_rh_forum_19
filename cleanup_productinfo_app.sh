#!/bin/bash

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# And login as the kubeadmin user

oc_login

#  This has a simple cleanup
echo "Deleting the project productinfo"
echo "This might take a couple of minutes to return"
oc delete project productinfo

#!/bin/bash
# 
# Reference docs/Troubleshooting.md for background
#
# We need to update the container version for the certified-operators container
# if we're running OpenShift 4.1.3
#

source ocp.env
source functions

oc_login

PATCH_VERSION="4.1.3"
#oc patch dc --patch='{"spec":{"template":{"spec":{"containers":[{"name": "", "image":"image-name:tag"}]}}}}' -n openshift-marketplace

# This will roll the patch level back to the existing 4.1.3 version
#oc patch deployment certified-operators --patch='{"spec":{"template":{"spec":{"containers":[{"name": "certified-operators", "image":"quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:e754b2926cd9f1c65412f00223e0699c9676d63e49b0999f16f43003e356a411"}]}}}}' -n openshift-marketplace

OC_VERSION=`oc_version`

if [ "${OC_VERSION}" == "${PATCH_VERSION}" ]; then
    
    printInfo "We have OpenShift ${PATCH_VERSION}"
    printInfo "  - First we'll scale down the replica set for the certified-operators"
    oc scale --replicas=0 deployment/certified-operators -n openshift-marketplace

    printInfo "  - patching the deployment for certified-operators to container image from 4.1.17"
    oc patch deployment certified-operators --patch='{"spec":{"template":{"spec":{"containers":[{"name": "certified-operators", "image":"quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:21fb64b516e6d592ae925a8196f31f6ebe6c5c84c3dbee095c034bdd62ff132f"}]}}}}' -n openshift-marketplace

    printInfo "  - Now delete the old replicasets"
    oc delete -n openshift-marketplace replicasets -l marketplace.catalogSourceConfig=certified-operators
    printInfo "  - Now we'll scale the copies of certified-operators back upto 1"
    oc scale --replicas=1 deployment/certified-operators -n openshift-marketplace

else
    printWarning "We have OpenShift ${OC_VERSION}"
    printInfo "  - deployment for certified-operators will not be patched"
    printInfo "  - double check the statue of the pods in the openshift-marketplace namespace"
    printInfo "  - oc get pods -n openshift-marketplace"
fi


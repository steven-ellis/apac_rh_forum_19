#!/bin/bash
# 
# 
#
# If you want to create your own 
#  htpasswd -c -B demo.admin.htpasswd admin

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
    printInfo "  - patching the deployment for certified-operators to container from 4.1.17"
    oc patch deployment certified-operators --patch='{"spec":{"template":{"spec":{"containers":[{"name": "certified-operators", "image":"quay.io/openshift-release-dev/ocp-v4.0-art-dev@sha256:21fb64b516e6d592ae925a8196f31f6ebe6c5c84c3dbee095c034bdd62ff132f"}]}}}}' -n openshift-marketplace

else
    printWarning "We have OpenShift ${OC_VERSION}"
    printInfo "  - deployment for certified-operators will not be patched"
fi


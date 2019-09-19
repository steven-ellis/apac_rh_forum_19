#!/bin/bash
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=codeready-workspaces

printInfo "Importing quarkus imagestream"
oc create -n openshift -f https://raw.githubusercontent.com/jumperwire/codeready-workspaces/master/quarkus-stack.imagestream.yaml

oc import-image --all quarkus-stack -n openshift

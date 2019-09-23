#!/bin/bash
#
# Deploy or cleanup a quarkus install
# 
# See demo docs under
#  docs/Quarkus.md
#

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# And login as the kubeadmin user

#oc login -u ${OCP_USER} -p ${OCP_PASS} ${OCP_ENDPOINT} --insecure-skip-tls-verify=false

OCP_NAMESPACE=supersonic-subatomic-java

# Ideally we should be cloning the repo locally for better performance
REPO_URL="https://raw.githubusercontent.com/jumperwire/supersonic-subatomic-java/master"

setup_quarkus()
{
    printInfo "Create the ${OCP_NAMESPACE} namespace"
    oc new-project ${OCP_NAMESPACE}

    printInfo "Deploy big fat java"
    oc apply -f ${REPO_URL}/deploy-big-fat-java-to-race-track.yaml
    
    printInfo "Deploy supersonic-subatomic java"
    oc apply -f ${REPO_URL}/deploy-supersonic-subatomic-java-to-race-track.yaml
    
    printInfo "Create big fat java service"
    oc apply -f ${REPO_URL}/service-big-fat-java.yaml
    
    printInfo "Create supersonic-subatomic java service"
    oc apply -f ${REPO_URL}/service-supersonic-subatomic-java.yaml
    
    printInfo "Create big fat java route"
    oc expose service big-fat-java
    
    printInfo "Create supersonic-subatomic java route"
    oc expose service supersonic-subatomic-java
}

delete_quarkus()
{
    printInfo "Remove the service routes"
    oc delete service supersonic-subatomic-java -n ${OCP_NAMESPACE}
    oc delete service big-fat-java  -n ${OCP_NAMESPACE}

    printInfo "Then remove the project ${OCP_NAMESPACE}"
    oc delete namespace ${OCP_NAMESPACE}
}

scale_java()
{
    printInfo "Scaling big fat java to ${1} pod(s)"
    oc scale --replicas=${1} deployment.apps big-fat-java -n ${OCP_NAMESPACE}
}
    
scale_quarkus()
{
    printInfo "Scaling quarkus to ${1} pod(s)"
    oc scale --replicas=${1} deployment.apps supersonic-subatomic-java -n ${OCP_NAMESPACE}
}

rc_watch()
{
    watch oc get replicaset -n ${OCP_NAMESPACE}
}
        
rc_status()
{
    oc get replicaset -n ${OCP_NAMESPACE}
}
        
case "$1" in
  setup|deploy)
        oc_login
        setup_quarkus
        ;;
  scale_down)
        oc_login
        scale_java 1
        scale_quarkus 1
        rc_status
        ;;
  scale_java)
        oc_login
        scale_java 100
        ;;
  scale_quarkus)
        oc_login
        scale_quarkus 100
        ;;
  scale_up|scale)
        oc_login
        COUNT=${100:-$2}
        scale_quarkus $COUNT
        scale_java $COUNT
        rc_watch
        ;;
  status)
        rc_status
        ;;
  watch)
        rc_watch
        ;;
  delete|remove)
        oc_login
        delete_quarkus
        ;;
  *)
        echo "Usage: $N {setup|scale_java|scale_quarkus|scale_up|scale N|scale_down|status|watch|delete}" >&2
        exit 1
        ;;
esac

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
    
    printInfo "Add SCC to User"
    oc adm policy add-scc-to-user privileged -z default -n ${OCP_NAMESPACE}

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

# taint workers
#
# We use taints to manage workload assignment
# This prevents other workloads consuming out quarkus and java worker nodes
# 
# $1 = node role
# $2 = taint - eg racetrack:NoExecute
#
taint_workers ()
{
    oc adm taint nodes -l role=${1}-node  ${2}
}

untaint_workers ()
{
    oc adm taint nodes -l role=${1}-node  ${2}-
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
  setup|deploy|create)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
	    printWarning "Project supersonic-subatomic-java is already deployed - Exiting"
        else
            setup_quarkus
        fi
        ;;
  scale_down)
        oc_login
        scale_java 1
        scale_quarkus 1
        rc_status
        ;;
  scale_java)
        oc_login
        scale_java 50
        ;;
  scale_quarkus)
        oc_login
        scale_quarkus 50
        ;;
  scale_up|scale)
        oc_login
        if [ "${2}a" == "a" ]; then
          COUNT=50
        else
          COUNT=${2}
        fi
        #COUNT=${50:-$2}
        scale_quarkus $COUNT
        scale_java $COUNT
        rc_watch
        ;;
  status)
        if (projectExists  ${OCP_NAMESPACE}); then
            rc_status
        fi
        ;;
  watch)
        if (projectExists  ${OCP_NAMESPACE}); then
            rc_watch
        fi
        ;;
  taint)
        taint_workers quarkus "racetrack=true:NoExecute"
        taint_workers java "racetrack=true:NoExecute"
        ;;
  untaint)
        untaint_workers quarkus racetrack
        untaint_workers java racetrack
        ;;
  delete|remove)
        oc_login
        if (projectExists  ${OCP_NAMESPACE}); then
            delete_quarkus
        fi
        ;;
  *)
        echo "Usage: $N {setup|scale_java|scale_quarkus|scale_up|scale N|scale_down|status|watch|delete}" >&2
        echo " status - shows the current replicaset value"
        echo " watch  - is the same a status but uses watch to monitor output"
        echo " taint|untaint set/clear taints against nodes tagged quarkus-role and java-node"
        echo "               These taints are used to make sure maximum resources are available for the demo"
        exit 1
        ;;
esac

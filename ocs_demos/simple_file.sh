
#!/bin/bash
#
# This leverages a simple file demo
#  - https://github.com/christianh814/openshift-php-upload-demo
# 
# Creates a new OpenShift file upload project.
#

source ./ocp.env
source ./functions

OCP_NAMESPACE=my-shared-storage

deploy_simple_file ()
{

    printInfo "Deploying our Simple File Demo into ${OCP_NAMESPACE}"
    oc new-project my-shared-storage
    oc new-app openshift/php:7.1~https://github.com/christianh814/openshift-php-upload-demo --name=file-uploader
    printInfo "Monitor the application logs while the code deploys"
    sleep 2
    oc logs -f bc/file-uploader

    printInfo "We should see some initial build/deploy pods active"
    oc get pods  -n ${OCP_NAMESPACE}
    printInfo "Take a short pause while we wait for the app to start"
    # We need an additional sleep here to make sure
    # the file-uploader pod is starting up
    sleep 7
    oc_wait_for  pod file-uploader app ${OCP_NAMESPACE}
    
    oc project ${OCP_NAMESPACE}
    oc expose svc/file-uploader
    printInfo "Scaling our Simple File Demo to 3 replicas"
    oc scale --replicas=3 dc/file-uploader
    oc get route

}

cleanup_simple_file ()
{
    printInfo "Starting cleanup of deployed resources in ${OCP_NAMESPACE}"
    oc delete route file-uploader -n ${OCP_NAMESPACE}

    # in theory we should really tidy up any PVCs

    printInfo "Deleting the project ${OCP_NAMESPACE}"
    printInfo "This might take a couple of minutes to return"

    oc delete project ${OCP_NAMESPACE}
}

status_simple_file ()
{
    printInfo "Current pods for file-uploader in ${OCP_NAMESPACE}"
    oc get pods -l app=file-uploader

    printInfo "Checking on route for file-uploader in ${OCP_NAMESPACE}"
    echo "    http://`oc get route file-uploader -n ${OCP_NAMESPACE} --template "{{.spec.host}}"`"

}

file_check ()
{
    printInfo "Looking inside our file-uploader pods stored files"
    oc project ${OCP_NAMESPACE}

    # Check for files
    for pod in $(oc get pod -l app=file-uploader --no-headers | awk '{print $1}'); do echo $pod; oc rsh $pod ls -hl uploaded; done
}

watch_pods ()
{
    oc project ${OCP_NAMESPACE}
    oc get pods -l app=file-uploader
    watch "echo 'wait for the file-uploaded pods to be Running'; oc get pods -n ${OCP_NAMESPACE}"
}

ocs_storage_class ()
{
    # This make sure the demo will work with upstream rook
    # in addition to our GA of OCS
    if has_sc ocs-storagecluster-cephfs; then
      WORKSPACE_PVCS=ocs-storagecluster-cephfs
    else
      WORKSPACE_PVCS=csi-cephfs
    fi

    oc set volume dc/file-uploader --add --name=my-shared-ceph-storage -t pvc --claim-mode=ReadWriteMany \
    --claim-size=1Gi --claim-name=ceph-shared-storage --mount-path=/opt/app-root/src/uploaded \
    --claim-class=${WORKSPACE_PVCS}


}

case "$1" in
  setup)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
	    printWarning "Simple File Demo already deployed in ${OCP_NAMESPACE} - Exiting"
        else
            deploy_simple_file
            status_simple_file
        fi
        ;;
  status)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            status_simple_file
        fi
        ;;
  check|files)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            file_check
        fi
        ;;

  ocs|rook)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            ocs_storage_class
            watch_pods
        fi
        ;;

  delete|cleanup|remove)
        oc_login
        if (projectExists ${OCP_NAMESPACE}); then
            cleanup_simple_file
        fi
        ;;
  *)
	echo "Usage: $1 {setup|status|check|ocs|rook|delete|cleanup|remove}" >&2
        exit 1
        ;;
esac




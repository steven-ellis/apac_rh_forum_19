#!/bin/bash
#
# Wrapper script to deploy and remove all apps/services
# in the correct order
#
# TODO
#  - consolidate login code to speed up deployment
#

source ./ocp.env
source ./functions

deploy_apps ()
{

    printInfo "Create our htpass based users on cluster ${OCP_DOMAIN}"
    ocp_htpass.sh

    printInfo "Deploying all apps and services into cluster ${OCP_DOMAIN}"

    ./3scale.sh

    ./service_mesh.sh setup
    ./productinfo_app.sh setup
    ./couchbase.sh setup
    ./quarkus.sh setup

    ./fuse74.sh setup
    ./bigpharmfusedeploy.sh setup


    printInfo "Deploying all CRW elements into cluster ${OCP_DOMAIN}"
    ./deploy_crw_ocp4.sh -d -p=codeready-workspaces
    ./crw_imagestream.sh
    ./crw_create_quarkus_workspace.sh
    ./crw_create_nodejs_workspace.sh
}

remove_apps ()
{        
    printInfo "Removing all apps and services from cluster ${OCP_DOMAIN}"
    printWarning "We need to validate the process for cleanup up CRW"
    printWarning "This does not remove any imported imagestreames"
    ./cleanup_crw_ocp4.sh -c -p=codeready-workspaces

    printInfo "Remove the bigpharm app"
    ./bigpharmfusedeploy.sh cleanup
    printWarning "Can't currently clean up the Fuse deployment"

    ./quarkus.sh delete
    ./scale_workers.sh down

    ./couchbase.sh delete
    ./productinfo_app.sh cleanup
    ./service_mesh.sh delete
    ./cleanup_3scale.sh

}

case "$1" in
  setup)
        #oc_login
        deploy_apps
        ;;
  delete|cleanup|remove)
        #oc_login
        remove_apps
        ;;
  *)
        echo "Usage: $N {setup|remove|cleanup}" >&2
        exit 1
        ;;
esac


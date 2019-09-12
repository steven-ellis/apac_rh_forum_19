#!/bin/bash

source ./ocp.env
source ./functions
source ./ocpfuse74.env

OCP_NAMESPACE=bigpharmfuse

load_drugs_data()
{
	appPod=`oc get pods | grep Running | grep -v -i deploy | awk -F" " '{print $1}'`
	logstmt=`oc logs ${appPod} | tail -1`
        if [[ $logstmt == *"After Application Started"* ]]; then
		oc rsync ./bigpharm_data/ "${appPod}":/deployments/inputdir
		echo "Data loading is completed. Please check the logs"
	else
		echo "Application has not started yet. Please load the data after the app is started."
	fi

}

update_svc_config()
{
	sleep 10
	echo "Changing the SVC Port...."
	sleep 5
	clusterIp=`oc get svc | grep "bigpharm" | awk -F" " '{print $3}'`
	cp bigpharmsvcconfig.yaml tmpsvc.yaml
	sed -i.bak "s/clusterIP: 000.00.00.0/clusterIP: ${clusterIp}/g" tmpsvc.yaml
	#cmd="sed -i '.bak' 's/clusterIP: 000.00.00.0/clusterIP: ${clusterIp}/g' tmpsvc.yaml"
	#eval $cmd 
	# Replace the svc config to listen on port 8080
	oc replace -f tmpsvc.yaml
	sleep 3
	oc get svc
	#rm tmpsvc.yaml tmpsvc.yaml.bak
}

create_bigpharm_route()
{
	sleep 2
	oc expose svc/bigpharm
}

test_endpoint()
{
	echo -en "To validate the rest endpoint. Execute the below command\n\n"
	oc get route | grep bigpharm | awk -F" " '{print "curl -k http://"$2"/bigPharm/drugid/DR1010"}'
	echo -en "\n\n"

}

pre_setup ()
{
    oc logout 2</dev/null

    oc_login

}

deploy_bigpharm()
{
    #Create new project for BigPharm Fuse deployment
    oc new-project ${OCP_NAMESPACE}
    oc project ${OCP_NAMESPACE}

    # Deploy the BigPharm Drugs Fuse image.
    oc new-app --docker-image="balajirb/bigpharm:latest" --name bigpharm
    echo "Deployment in Progress ...."
    sleep 20
    echo "Deployment is still in Progress ...."
    sleep 20
    oc_wait_for  pod bigpharm app ${OCP_NAMESPACE}
    appPod=`oc get pods | grep Running | grep -v -i deploy | awk -F" " '{print $1}'`

    if [[ $appPod == *"bigpharm"* ]]; then
      echo "Deployment is completed."
      echo "Updating the Service to listen on port#8080"
      update_svc_config
      sleep 2
      echo "Creating Route for the Big Pharm service."
      create_bigpharm_route
      sleep 2
      echo "Load the drugs data..."
      load_drugs_data
      sleep 2
      test_endpoint
    else
      echo "Check the deployment status. oc get pods"
    fi 
}

cleanup_bigpharm()
{
    oc project ${OCP_NAMESPACE}
    oc delete namespace ${OCP_NAMESPACE}

}


case "$1" in
  setup)
        pre_setup 
        deploy_bigpharm
        ;;
  delete|cleanup|remove)
        pre_setup 
        cleanup_bigpharm
        ;;
  *)
        echo "Usage: $N {setup|cleanup}" >&2
        exit 1
        ;;
esac


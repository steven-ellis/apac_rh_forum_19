#!/bin/bash
#
# Setup Fuse 7.4 into our OpenShift envioronment
#
# Requirements
# ocpfuse74.env - with additional registry requirements for the images
#  DOCKER_REGISTRY_URL=
#  DOCKER_SVCACCNT_USERNAME=
#  DOCKER_SVCACCNT_PASSWORD=
#

source ./ocp.env
source ./functions
source ./ocpfuse74.env

install_fuse_imagestream()
{
	BASEURL=https://raw.githubusercontent.com/jboss-fuse/application-templates/application-templates-2.1.fuse-740025-redhat-00003
	oc replace -n openshift -f ${BASEURL}/fis-image-streams.json
}

install_fuse_templates()
{
echo "Installing Fuse Templates" 
	# Install Quick Start Templates.
	for template in eap-camel-amq-template.json eap-camel-cdi-template.json eap-camel-cxf-jaxrs-template.json eap-camel-cxf-jaxws-template.json eap-camel-jpa-template.json   karaf-camel-amq-template.json karaf-camel-log-template.json karaf-camel-rest-sql-template.json karaf-cxf-rest-template.json spring-boot-camel-amq-template.json spring-boot-camel-config-template.json spring-boot-camel-drools-template.json spring-boot-camel-infinispan-template.json spring-boot-camel-rest-sql-template.json spring-boot-camel-template.json spring-boot-camel-xa-template.json spring-boot-camel-xml-template.json spring-boot-cxf-jaxrs-template.json spring-boot-cxf-jaxws-template.json;
	do
	oc create -n openshift -f https://raw.githubusercontent.com/jboss-fuse/application-templates/application-templates-2.1.fuse-740025-redhat-00003/quickstarts/${template}
	done;

	# Install the templates for the Fuse Console.

	oc create -n openshift -f https://raw.githubusercontent.com/jboss-fuse/application-templates/application-templates-2.1.fuse-740025-redhat-00003/fis-console-cluster-template.json

	oc create -n openshift -f https://raw.githubusercontent.com/jboss-fuse/application-templates/application-templates-2.1.fuse-740025-redhat-00003/fis-console-namespace-template.json
}

update_sample_operator_config()
{
        echo "Updating the sample Fuse Operator config"
	cp ./backup/configs.samples.operator.openshift.io.original tmp.yaml
	totalLines=`wc -l tmp.yaml | tr -dc '0-9'`
	indexPos=`awk "/managementState: Managed/{ print NR; exit }" tmp.yaml`
	sed -n "1,${indexPos}p" tmp.yaml > tmp1.yaml
	#cmd="sed -n "1,${indexPos}p" tmp.yaml > tmp1.yaml"
	#eval $cmd
	indexPos=$[indexPos+1]
	sed -n "${indexPos},${totalLines}p" tmp.yaml > tmp3.yaml
	#cmd="sed -n '${indexPos},${totalLines}p' tmp.yaml > tmp3.yaml"
	#eval $cmd
	cp additionalParams.yaml tmp2.yaml
	cat tmp[1-3].yaml > tmp123.yaml
	sed -i.bak "/resourceVersion/d" tmp123.yaml
	sed -i.bak "/creationTimestamp/d" tmp123.yaml
	sed -i.bak "/uid:/d" tmp123.yaml
	sed -i.bak "/version:/d" tmp123.yaml
	oc replace -f tmp123.yaml
	rm tmp*yaml*
}

oc logout 2</dev/null

oc_login

mkdir -p backup

oc project openshift

oc create -n openshift secret docker-registry imagestreamsecret --docker-server=$DOCKER_REGISTRY_URL --docker-username=DOCKER_SVCACCNT_USERNAME --docker-password=$DOCKER_SVCACCNT_PASSWORD 

oc get configs.samples.operator.openshift.io -n openshift-cluster-samples-operator -o yaml > ./backup/configs.samples.operator.openshift.io.original

oc get template -n openshift >./backup/octemplates.original

update_sample_operator_config;

install_fuse_imagestream;

install_fuse_templates;

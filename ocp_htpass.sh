#
# Based on 
#  - https://docs.openshift.com/container-platform/4.1/authentication/identity_providers/configuring-htpasswd-identity-provider.html#identity-provider-creating-htpasswd-file-linux_configuring-htpasswd-identity-provider
#
# If you want to create your own 
#  htpasswd -c -B demo.admin.htpasswd admin

source ocp.env
source functions

oc_login

oc create secret generic htpass-secret --from-file=htpasswd=demo.admin.htpasswd  -n openshift-config

oc apply -f ocp_htpass.yaml 

oc adm policy add-cluster-role-to-user cluster-admin admin


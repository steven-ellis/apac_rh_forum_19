#!/bin/bash
#
# Provide instructions on extending the LB Timeout for CRW
# 
# See demo docs under
#  docs/CodeReadyWorkspaces.md
#

# Step 0 - Our master environment
source ./ocp.env
source ./functions

# And login as the kubeadmin user
#oc_login

#OCP_DOMAIN=rhte.openshift.steven.geek.nz
OCP_DOMAIN=cluster-akl-d12b.sandbox1049.opentlc.com
BASTION=${OCP_DOMAIN/cluster-/bastion.}

printInfo "We’ve got an issue where the Load Balancer settings are causing a timeout for the CRW console."
printInfo "The following process need scripting."
printWarning "You will need the “ssh” command given in the rhpds email, log into your Bastion Host using ssh"
printInfo "If your using RHPDS your bastion should be ${BASTION}"
echo "ssh ${OCP_USERNAME}@${BASTION}"
printInfo "set the default AWS CLI region configuration using the following command:"

echo "sudo -u ec2-user aws configure"
echo ""

printInfo "just press “enter” for all prompts except the prompt for region, which for our RHPDS environmen should be “us-east-2”."

printInfo "After configuring the region, discover the name of your specific load balancer for your ocp instance using:"
echo ""
cat <<EOF
sudo -u ec2-user aws elb describe-load-balancers | \\
jq '.LoadBalancerDescriptions | map(select( .DNSName == "'\$(oc get svc router-default -n openshift-ingress -o jsonpath='{.status.loadBalancer.ingress[].hostname}')'" ))' | \\
grep LoadBalancerName

EOF
printInfo "Then using the name of the load balancer, run:"
cat <<EOF
sudo -u ec2-user aws elb modify-load-balancer-attributes \\
  --load-balancer-name <name> \\
  --load-balancer-attributes "{\"ConnectionSettings\":{\"IdleTimeout\":300}}"

EOF
printInfo "Replace <name> with the name of *your* load balancer."
printInfo "This sets the default elastic loadbalancer timeout to 5 minutes."

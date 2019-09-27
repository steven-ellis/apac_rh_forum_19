# Code Ready Workspaces Deployment
For this we are leveraging an existing CRW deployment script from [Agnostid](./Agnosticd.md).

## Deploying CRW

Make sure we're logged in correctly to our OpenShift instance,
and we have csi-cephfs and rook-ceph-block storage classes
```
./setup.sh
oc get sc
```
Output should look similar to
```
NAME                        PROVISIONER                     AGE
csi-cephfs                  rook-ceph.cephfs.csi.ceph.com   44h
gp2                         kubernetes.io/aws-ebs           2d
rook-ceph-block (default)   rook-ceph.rbd.csi.ceph.com      44h
```

Deploy CRW Operator into the required namespace/project
```
./deploy_crw_ocp4.sh -d -p=<namespace>
```

The process should take approximately 5-10 minutes

We then import the Quarkus image we need for our workspace
```
./crw_imagestream.sh
```

Then create a quarkus  and nodejs workspaces
```
./crw_create_quarkus_workspace.sh
./crw_create_nodejs_workspace.sh
```

## Deployment Scripts Reference
Existing upstream script lives under

```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/deploy.sh.ocp4`
```
and has been copied to - ```deploy_crw_ocp4.sh```

In addition we need to copy their CRD from
```
agnosticd/ansible/roles/ocp-workload-rhte19-optaplanner-101-lab-infra/files/codeready-workspaces-operator-installer/custom-resource.yaml
```
to - ```crw-custom-resource.yaml```

Once we've got this baseline we can tweak the scripts to deploy the way we want

## Configure CHE Config Map
We need to do this so we pickup the correct storage
```
CHE_INFRA_KUBERNETES_PVC_STORAGE__CLASS__NAME: "csi-cephfs"
```

To check the current config map
```
oc get configmap che -o yaml -n crw
```

Upstream Reference
 * https://github.com/eclipse/che-operator/blob/master/deploy/crds/org_v1_che_cr.yaml

We simply need to update our ```crw-custom-resource.yaml``` with 
```
    storage:
      pvcStrategy: 'per-workspace'
      pvcClaimSize: 1Gi
      # keep blank unless you need to use a non default storage class for Postgres PVC
      postgresPVCStorageClassName: ''
      # keep blank unless you need to use a non default storage class for workspace PVC(s)
      workspacePVCStorageClassName: 'csi-cephfs'
```

## CRW Loadbalancer Timout
We’ve got an issue where the Load Balancer settings are causing a timeout for the CRW console. The following process need scripting.

An initial wrapper script has been writter under ```crw_lb_timeout.sh```, but the manual steps are

- using the “ssh” command given in the rhpds email, log into your Bastion Host using ssh
- set the default AWS CLI region configuration using the following command:

```sudo -u ec2-user aws configure```

just press “enter” for all prompts except the prompt for region, which for our RHPDS environmen should be “us-east-2”.

After configuring the region, discover the name of your specific load balancer for your ocp instance using:
```
sudo -u ec2-user aws elb describe-load-balancers | \\
jq '.LoadBalancerDescriptions | map(select( .DNSName == "'\$(oc get svc router-default -n openshift-ingress -o jsonpath='{.status.loadBalancer.ingress[].hostname}')'" ))' | \\
grep LoadBalancerName
```
Then using the name of the load balancer, run:
```
sudo -u ec2-user aws elb modify-load-balancer-attributes \
  --load-balancer-name <name> \
  --load-balancer-attributes "{\"ConnectionSettings\":{\"IdleTimeout\":300}}"
```
Replace <name> with the name of *your* load balancer. This sets the default elastic loadbalancer timeout to 5 minutes.


# Using OpenShift 4.x Installer
OpenShift 4.x uses a new GO based installer that can provision the
cloud/virtual infrastructure in addition to deploying OpenShift

 - https://github.com/openshift/installer/

In addition to Red Hat RHPDS/OPEN based demo and workshop environments
we can deploy our OpenShift Demo directly onto a public cloud deployment
of OpenShift

## Grabbing the OpenShift installer

If you need the installer for a specific version of OpenShift look at the
available releases at https://openshift-release.svc.ci.openshift.org/

Then use `oc adm` to extract the installer for a specific version
```
oc adm release extract --tools quay.io/openshift-release-dev/ocp-release:4.1.13
```

## AWS Deployment

This has currently been tested with the following AWS deployed versions of OpenShift

 * 4.1.3
 * 4.1.13
 * [4.2.x](./OpenShift_4.2.md)

### AWS Pre-requisites
For the relevant pre-requisites see

 - https://github.com/openshift/installer/blob/release-4.1/docs/user/aws/README.md

In particular you will need a domain configured for Route53

### AWS Deployment Steps

 * Confirm pre-requisites above
 * Create
    * ~/.aws/credentials
    * ~/.aws/config
 * OpenShift Pull Secret c/o
    * https://cloud.redhat.com/openshift/install
 * Correctly versioned OpenShift Installer - see above


Run the following to create a cluster config 
and select the AWS zone you wish to deploy into.
You will need your pull secret as part of this step`
```
./openshift-install --dir ocp_<version> create install-config
```

The default instance size for workers is to small for our demo environment.
***m4.large*** but for our demo we're running ***m5.2xlarge***.

Edit ocp_<version>/install-config.yaml and update the instance size for the workers/compute
```
compute:
- hyperthreading: Enabled
  name: worker
  platform:
    aws:
      type: m5.2xlarge
  replicas: 3
```

Then create a backup of our configured install directory so we can re-use for repeatable
deployments
```
cp -a ocp_<version> ocp_<version>.orig
```
Finally build our cluster
```
./openshift-install create cluster --dir ocp_<version>
```

If you want to override the Cluster Version and know the specific version follow

 * https://github.com/openshift/installer/blob/master/docs/dev/alternative_release_image_sources.md

You can set an environment variable to point to the specific version providing
your OpenShift Pull secret has the required access. Note that this can be problematic and we
***recommend*** you use the correct installer version.
```
OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=quay.io/openshift-release-dev/ocp-release:4.1.13

./openshift-install create cluster 
```

This will return with the cluster details and credentials after 20-30 minutes


If the install times out you can use the openshift-install tool to wait for the
installationt to complete
```
./openshift-install wait-for bootstrap-complete --dir ocp_<version>
```


### Monitoring the AWS Build
In the configuration directory an installer log will be created
```
tail -f ocp_<version>/.openshift_install.log 
```

In addition you can ssh into the bootstrap node to see how the install is progressing
```
# use the aws tool to find out our Public IP Address for the bootstrap node
aws ec2 describe-instances --filters  \
  "Name=tag:Name,Values=*bootstrap" --query "Reservations[].Instances[].[PublicDnsName,Tags[?Key=='Name'].Value]" \
  --output=text


# SSH  into the host
ssh core@<public_dns>
```


### Clean up / Delete Cluster on AWS
To clean up your environment run
```
./openshift-install destroy cluster 
# OR
./openshift-install destroy cluster --dir ocp_<version>
```

## Azure Deployment

To be tested

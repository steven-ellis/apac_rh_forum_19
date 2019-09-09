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

For the relevant pre-requisites see

 - https://github.com/openshift/installer/blob/release-4.1/docs/user/aws/README.md

Deployment Steps

 * Confirm pre-requisites above
 * Create
    * ~/.aws/credentials
    * ~/.aws/config
 * OpenShift Pull Secret c/o
    * https://cloud.redhat.com/openshift/install
 * Correctly versioned OpenShift Installer - see above


Run the following and select the AWS zone you wish to deploy into
```
./openshift-install create cluster 
```

If you want to override the Cluster Version and know the specific version follow

 * https://github.com/openshift/installer/blob/master/docs/dev/alternative_release_image_sources.md

You can set an environment variable to point to the specific version providing
your OpenShift Pull secret has the required access
```
OPENSHIFT_INSTALL_RELEASE_IMAGE_OVERRIDE=quay.io/openshift-release-dev/ocp-release:4.1.13

./openshift-install create cluster 
```

This will return with the cluster details and credentials after 20-30 minutes

To clean up your environment run
```
./openshift-install delete cluster 
```

## Azure Deployment

To be tested

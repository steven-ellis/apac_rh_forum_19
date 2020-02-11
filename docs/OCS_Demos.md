# OpenShift Container Storage Demos
Demo deployment script for various OCS centic demos

* [Pre-Requisites](#pre-requisites)
* [Simple File Demo](#simple-file-demo)

## Pre-requisites
1. OpenShift 4.1 / 4.2 4.3 instance created via
    * RHPDS deployed "OCP and Container Storage for Admins"
    * RHPDS deployed "OpenShift 4.2 Workshop"
    * AgnosticD deployed OCP4 environment
    * [AWS deployed](./OpenShiftInstaller.md) vanilla environment via openshift-installer
1. Updated `ocp.env` with login details for above environment
    * use `ocp.env.sample` as an example of the data required
1. Deployed OCS or Rook storage
    * Reference OCS Deployment under [OpenShift Demo Notes](./OpenShiftDemo.md)

## Simple File Demo

This shows off a basic RWX shared file store usecase backed via OCS


This takes approx 5 minutes to deploy. We run a tail on the build pod
to see the progress of the build.

```
./ocs_demos/simple_file.sh setup
```

Confirm we've got a valid route to the application

```
./ocs_demos/simple_file.sh status
```

Browse to the supplied route in your web browser and upload a file
or two. Then check the pods to see which pod your file has been
uploaded to

```
./ocs_demos/simple_file.sh files
```

You should notice that the files aren't present on all of the pods as
our environment isn't backed with shared storage. Lets update the
configuration so that we are using OCS for RWX file.

```
./ocs_demos/simple_file.sh ocs
```

We need to allow a couple of minutes for the application pods to
re-deploy as we've changed the storage configuration. Once we got
**three** updated file-uploader pods hit *CTRL-C* to continue.

Browse back to the file uploader or type
```/ocs_demos/simple_file.sh status ```
if you need to confirm the URL.
Now upload some files again before re-running

```
./ocs_demos/simple_file.sh files
```

You should now see that all of the files are present on all ***three***
members of the file-uploader service.

To clean up the environment when you're finished run

```
./ocs_demos/simple_file.sh cleanup
```

The project may take a few minutes to clean up as it had to make sure
the provisioned OCS storage has been released.

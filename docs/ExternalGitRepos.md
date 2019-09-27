# External Git Repos
We currently use a number of other repos as part of the demo deployment

**Storage**

* [Rook](https://github.com/rook/rook/)
* [OpenShift CNS TestDrive](https://github.com/openshift/openshift-cns-testdrive)

and we need to make sure we're deploying with a known working commit from their trees

These are repositories are initially copied via [setup.sh](../setup.sh)

**OpenShift Environment**

Fuse 7.4

- we are using a tag *application-templates-2.1.fuse-740025-redhat-00003*
    * https://github.com/jboss-fuse/application-templates/tree/application-templates-2.1.fuse-740025-redhat-00003
    * https://raw.githubusercontent.com/jboss-fuse/application-templates/application-templates-2.1.fuse-740025-redhat-00003

Istio / Service Mesh

- we are using currently using master
    * https://github.com/jumperwire/jumperwire/servicemesh/
    * https://raw.githubusercontent.com/jumperwire/servicemesh/master/maistra-operator.yaml
    * https://raw.githubusercontent.com/jumperwire/servicemesh/master/basic-install.yaml

**Demo Code**

Code Ready Workspaces Demo

* https://github.com/che-samples/web-nodejs-sample
* https://github.com/jumperwire/quarkus-todo-app.git
* https://raw.githubusercontent.com/jumperwire/codeready-workspaces/master/quarkus-stack.imagestream.yaml

Product Info Demo

- we are using currently using master
    * https://github.com/jumperwire/jumperwire/productinfo/
    * https://raw.githubusercontent.com/jumperwire/productinfo/master/productinfo.yaml
    * https://raw.githubusercontent.com/jumperwire/productinfo/master/productinfo-gateway.yaml
    * https://raw.githubusercontent.com/jumperwire/productinfo/master/destination-rule.yaml
    * https://raw.githubusercontent.com/jumperwire/productinfo/master/virtual-service-all-v1.yaml

Quarkus

- we are using currently using master
    * https://github.com/jumperwire/jumperwire/supersonic-subatomic-java/
    * https://raw.githubusercontent.com/jumperwire/supersonic-subatomic-java/master"

# Storage Repo Validation

## Known Working Rook - 3 Sep 2019
master - b76ed665826b9302a2333e0526ff8d3cc1ac1ab3
```
cd rook.master
git checkout b76ed665826b9302a2333e0526ff8d3cc1ac1ab3
```

### Testing with tag v1.1.0-beta.0
This will will requir an updated Ceph image to v14.2.2-20190826 
via [deploy_ocs.sh](../deploy_ocs.sh)
```
cd rook.master
git fetch --tags
git checkout v1.1.0-beta.0
```
You should get the message
```
HEAD is now at 5c59a1e4 Merge pull request #3742 from travisn/debug-logging
```

## Known Working OpenShift CNS Test Drive - 3 Sep 2019
ocp4-prod - 965f529d63752819775b0a5e86fc0d3a92ff0495
```
cd content
git checkout 965f529d63752819775b0a5e86fc0d3a92ff0495
```

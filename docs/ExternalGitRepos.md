# External Git Repos
We currently use a number of other repos as part of the demo deployment

* [Rook](https://github.com/rook/rook/)
* [OpenShift CNS TestDrive](https://github.com/openshift/openshift-cns-testdrive)

and we need to make sure we're deploying with a known working commit from their trees

These are repositories are initially copied via [setup.sh](../setup.sh)

## Known Working Rook - 3 Sep 2019
master - b76ed665826b9302a2333e0526ff8d3cc1ac1ab3
```
cd rook.master
git checkout b76ed665826b9302a2333e0526ff8d3cc1ac1ab3
```

## Known Working OpenShift CNS Test Drive - 3 Sep 2019
ocp4-prod - 965f529d63752819775b0a5e86fc0d3a92ff0495
```
cd content
git checkout 965f529d63752819775b0a5e86fc0d3a92ff0495
```

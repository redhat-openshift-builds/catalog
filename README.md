# OpenShift Builds File-Based Catalog
This repository contains the file-based catalogs for Builds for OpenShift, for different OpenShift versions.

## Prerequisites
- podman
- yq
- kustomize
- opm

Some of these tools can be installed using the following `Makefile` target.
```shell
  make install
```

## Generating Catalog
The script `catalog.sh` can generate catalog for different OpenShift versions taking configurations from a file.
File `config.yaml` is a pre-configured config file and can be considered as the blueprint of the catalogs.
There is a `Makefile` target to generate catalogs.

To generate catalog for all OpenShift versions configured in the config file.
```shell
  make generate 
```

The `generate.sh` script can be used directly for more flexibility. 
Check the usage before generating.
```shell
  bash scripts/generate.sh help
```

### Other Parameters
To generate catalog for specific OpenShift versions. (Configurations in the config file are still required)
```shell
  make generate OCP=4.15
```
To add a specific bundle to existing catalogs
```shell
  make generate BUNDLE="registry.redhat.io/openshift-builds/openshift-builds-operator-bundle:test"
```
To generate catalog from scratch. (Previously generated files will be deleted)
```shell
  make generate OCP=4.15 REBUILD="true"
```
To override catalog directory in config file.
```shell
  make generate OCP=4.15 DIR="test-fbc"
```

The generation usually works in `delta` mode. Which means, bundles will be pulled and generated for the newly added 
bundldes in the config and added to the existing catalog. Other objects will be re-generated accordingly.
To generate everything from scratch, set `REBUILD="true"`.
Also, running the script for specific OpenShift version will only modify the content of that specific version folder.



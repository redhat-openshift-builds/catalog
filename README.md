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
The script `generate.sh` can generate catalog for different OpenShift versions taking configurations from a file.
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
make generate OCP=4.18
```
To add a specific bundle to existing catalogs
```shell
make generate BUNDLE="registry.redhat.io/openshift-builds/openshift-builds-operator-bundle:test"
```
To generate catalog from scratch. (Previously generated files will be deleted)
```shell
make generate OCP=4.18 REBUILD=true
```
To override catalog directory in config file.
```shell
make generate OCP=4.18 DIR="test-fbc"
```

The generation usually works in `delta` mode. Which means, bundles will be pulled and generated for the newly added 
bundles in the config and added to the existing catalog. Other objects will be re-generated accordingly.
To generate everything from scratch, set `REBUILD=true`.
Also, running the script for specific OpenShift version will only modify the content of that specific version folder.

## Building and Pushing Catalog

To build a catalog image locally:
```shell
make build OCP=4.18 VERSION=1.7
# Builds: localhost/openshift-builds-catalog:1.7-4.18
```

To build and push to a registry:
```shell
make push OCP=4.18 VERSION=1.7 REGISTRY=quay.io/myorg/myrepo
# Pushes: quay.io/myorg/myrepo/openshift-builds-catalog:1.7-4.18
```

## Get Catalog image for Testing

This repository includes a GitHub Actions workflow to automate catalog image generation for testing purpose.

### Running the Workflow

1. Go to **Actions** → **Generate and Push Catalog**
2. Click **Run workflow**
3. Fill in the inputs:

| Input | Description | Default |
|-------|-------------|---------|
| `ocp_versions` | Comma-separated OCP versions (e.g., `4.17,4.18`) or `all` | `all` |
| `bundle` | Specific bundle image to add (optional) | *(from config)* |
| `rebuild` | Generate catalog from scratch | `false` |
| `version` | Version tag for the catalog image | `test` |

### Output Images

The workflow pushes images to GitHub Container Registry with the following naming format:
```
ghcr.io/<owner>/<repo>/openshift-builds-catalog:<version>-<ocp>
```

Example: `ghcr.io/redhat-openshift-builds/catalog/openshift-builds-catalog:1.7-4.18`



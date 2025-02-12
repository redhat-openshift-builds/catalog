# The base image is expected to contain
# /bin/opm (with a serve subcommand) and /bin/grpc_health_probe
# Using brew.registry.redhat.io instead of registry.redhat.io since 4.18 is not release yet.
# brew.registry.redhat.io/rh-osbs/openshift-ose-operator-registry-rhel9:v4.18
# registry.redhat.io/openshift4/ose-operator-registry-rhel9:v4.18
FROM brew.registry.redhat.io/rh-osbs/openshift-ose-operator-registry-rhel9:v4.18

# Configure the entrypoint and command
ENTRYPOINT ["/bin/opm"]
CMD ["serve", "/configs", "--cache-dir=/tmp/cache"]

# Copy declarative config root into image at /configs and pre-populate serve cache
ADD openshift-builds-operator /configs/openshift-builds-operator
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]

# Set DC-specific label for the location of the DC root directory
# in the image
LABEL operators.operatorframework.io.index.configs.v1=/configs

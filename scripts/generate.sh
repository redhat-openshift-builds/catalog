#!/bin/bash

# Include common library functions
source ./scripts/common.sh

# Usage information about the script
help() {
  bold "\nUsage: catalog.sh [options] <config-file> \n"
  echo -e '
    -h \tDisplays this help.
    -b \tSpecify a single bundle to add.
    -p \tGenerate catalog in this path. If not specified, "directory" from config will be used.
    -r \tRegenerate the catalog from scratch.
    -t \tDirectory that will be used to generate temporary files. If not specified "temp" directory is created.
    -v \tOCP version to generate catalog for. If not specified, generates catalog for all version in config.
  '
}

# Generate Dockerfile
generate_dockerfile() {
  local version=$1 config=$2 path=$3
  local image package flags

  # Read configurations
  image=$(yq -e '.catalog.opmImage' "$config")
  package=$(yq -e '.catalog.packageName' "$config")

  # Create catalog directory and remove existing Dockerfile
  mkdir -p "$path/$version/$package"
  find "$path/$version" -maxdepth 1 -name "*Dockerfile" -type "f" -delete

  # Set opm image according to OCP version
  if [[ "$(printf '%s\n' "4.14" "$version" | sort -V | tail -n1)" == "4.14" ]]; then
    image="$image:v$version"
  else
    image="$image-rhel9:v$version"
  fi

  # Set SED_INPLACE for cross-platform compatibility (Linux/macOS)
  if [[ "$(uname)" == "Darwin" ]]; then
    flags=(-i '')
  else
    flags=(-i)
  fi

  # Generate Dockerfile
  opm generate dockerfile -i "$image" -b "$image" "$path/$version/$package"
  mv "$path/$version"/*.Dockerfile "$path/$version"/Dockerfile
  sed "${flags[@]}" "/ADD $package/s/$/\/$package/" "$path/$version"/Dockerfile
  success "Dockerfile"
}

# Generate olm basic template
generate_template() {
  local path=$1
  yq -n \
    ".schema = \"olm.template.basic\" |
    .entries = []" \
    > "$path/olm.template.basic.yaml"
}

# Generate 'olm.package.yaml'
generate_package() {
  local config=$1 path=$2
  local package icon description

  package=$(yq -e '.catalog.packageName' "$config")
  icon=$(yq -e '.catalog.iconFile' "$config")
  description=$(yq -e '.catalog.descriptionFile' "$config")

  # Render olm.package'
  opm init \
    --icon="$icon" \
    --description="$description" \
    --default-channel="latest" \
    --output="yaml" \
    "$package" > "$path/olm.package.yaml"

  success "Package"
}

# Generate 'olm.bundle.yam'
generate_bundles() {
  local config=$1 path=$2 bundle=$3
  local bundles

  # Check if specific bundle is provided as parameter. Then use that instead.
  if [[ -z ${bundle:-} ]]; then
    # Get bundles from configuration file
    readarray -t bundles < <(yq -e ".catalog.bundles[]" "$config")
  else
    # Use bundle from parameter
    bundles=( "$bundle" )
  fi

  # Create bundle file if it doesn't exist
  [[ ! -f "$path/olm.bundle.yaml" ]] && touch "$path/olm.bundle.yaml"

  # Add bundle entries to olm.bundle.yaml if it doesn't exists
  for bundle in "${bundles[@]}"; do
    if [[ $(yq ea "[ .image == \"$bundle\" ] | any" "$path/olm.bundle.yaml") == "false" ]]; then
      process "Bundle - Pulling $bundle"
      opm render "$bundle" \
        --output yaml \
        >> "$path/olm.bundle.yaml"
      clear
    fi
  done

  success "Bundles"
}

# Generate 'deprecation.yaml'
generate_deprecations() {
  local config=$1 path=$2
  local message bundle bundles channel channels versions package threshold threshold_version

  # Read configurations
  package=$(yq -e '.catalog.packageName' "$config");
  prefix=$(yq -e '.catalog.channelPrefix' "$config");
  threshold=$(yq -e '.catalog.deprecationThreshold' "$config");
  message=$(yq -e '.catalog.deprecationMessage' "$config");
  readarray -t versions < <(yq -N "\"$prefix-\" + .catalog.deprecatedVersions[]" "$config")

  # Get generated channels
  readarray -t channels < <(yq -N '.name | select(. != "latest")' "$path/olm.channel.yaml")

  # Set deprecation threshold version
  [[ $threshold < ${#channels[@]} ]] && threshold_version=${channels[-$threshold -1]} || threshold_version=""

  # Generate 'olm.deprecations' schema
  yq -n \
    ".schema = \"olm.deprecations\" |
    .package = \"$package\" |
    .entries = []" \
    > "$path/olm.deprecations.yaml"

  # Add deprecated objects
  for channel in "${channels[@]}"; do
    if (printf "%s\n" "${versions[@]}" | grep -q -x "$channel") ||
    [[ $(printf '%s\n' "$threshold_version" "$channel" | sort -V | tail -n1) == "$threshold_version" ]]; then
      # Add channel deprecation
      export DEPRECATED_VERSION=$channel
      export CURRENT_VERSION=${channels[-1]}
      yq -i \
        ".entries += [{
          \"reference\": {
            \"schema\": \"olm.channel\",
            \"name\": \"$channel\"
          },
          \"message\": \"$(printf "%s" "$message" | envsubst)\"
        }]" \
        "$path/olm.deprecations.yaml"

      # Add bundle deprecation
      readarray -t bundles < <(yq -eN "select(.name == \"$channel\").entries[].name" "$path/olm.channel.yaml")
      CURRENT_VERSION=$(yq -eN "select(.name == \"${channels[-1]}\").entries[-1].name" "$path/olm.channel.yaml")
      for bundle in "${bundles[@]}"; do
        export DEPRECATED_VERSION=$bundle
        yq -i \
          ".entries += [{
            \"reference\": {
              \"schema\": \"olm.bundle\",
              \"name\": \"$bundle\"
            },
            \"message\": \"$(printf "%s" "$message" | envsubst)\"
          }] | \
          .entries[].message style=\"double\"" \
          "$path/olm.deprecations.yaml"
      done
    fi
  done

  # Unset exported environment variables
  unset DEPRECATED_VERSION
  unset CURRENT_VERSION

  success "Deprecations"
}

# Generate 'olm.channel.yaml'
generate_channels() {
  local config=$1 path=$2
  local bundles package bundle object
  local version versions
  local channel previous_channel

  # Read configurations
  package=$(yq -e '.catalog.packageName' "$config")
  prefix=$(yq -e '.catalog.channelPrefix' "$config");
  readarray -t bundles < <(yq -N '.name' "$path/olm.bundle.yaml" | sort -V)
  readarray -t versions < <(yq -N '.properties[] | select(.type == "olm.package").value.version' "$path/olm.bundle.yaml" | sort -V)

  # Generate 'olm.template.basic'
  generate_template "$path"

  # Add channel 'latest'
  yq -i \
    ".entries += {
      \"schema\": \"olm.channel\",
      \"name\": \"latest\",
      \"package\": \"$package\",
      \"entries\": []
    }" \
    "$path/olm.template.basic.yaml"

#  minimum_version=${versions[0]}
  # # Alternative approach to extract using SemVer regexp
  # minimum_version=$(echo "${bundles[0]}" | grep -ioE "$SEMVER_PATTERN" | tr -d "[:alpha:]")

  for index in "${!versions[@]}"; do
    # Alternative approach to extract using SemVer regexp
    # version=$(echo "${bundles[index]}" | grep -ioE "$SEMVER_PATTERN" | tr -d "[:alpha:]")
    channel="$prefix-$(printf "%s" "${versions[index]}" | cut -d "." -f1-2)"

    # Add to 'latest' channel
    if [[ "$index" = 0 ]]; then
      object="{ \"name\":\"${bundles[index]}\" }"
    else
      object="{ \"name\": \"${bundles[index]}\",
              \"replaces\": \"${bundles[index-1]}\",
              \"skipRange\": \">=${versions[0]} <${versions[index]}\" }"
    fi
    yq -i \
      "(.entries[] | select(.name == \"latest\").entries) += $object" \
      "$path/olm.template.basic.yaml"

    # Add new channels for minor versions
    if [[ -z ${previous_channel+x} || "$channel" != "$previous_channel" ]]; then
      yq -i \
        ".entries += {
          \"schema\": \"olm.channel\",
          \"name\": \"$channel\",
          \"package\": \"$package\",
          \"entries\": []
        }" \
        "$path/olm.template.basic.yaml"
      previous_channel=$channel
    fi

# TODO: Check later if 'skipRange' is needed only at the tail of a channel update graph.
#    # Add entries in the new channel
#    if [[ "$((index + 1))" -lt "${#bundles[@]}" ]]; then
#      next_channel="builds-$(
#        printf "%s" "${bundles[index + 1]}" |
#        grep -ioE "$SEMVER_PATTERN" |
#        tr -d "[:alpha:]" |
#        cut -d "." -f1 -f2
#      )"
#    fi
#
#    if [[ ${bundles[index]} = "${bundles[-1]}" || "$channel" != "$next_channel" ]]; then
#      object="{ \"name\": \"${bundles[index]}\",
#              \"replaces\": \"${bundles[index-1]}\",
#              \"skipRange\": \">=${minimum_version} <${version}\" }"
#    else
#      object="{ \"name\": \"${bundles[index]}\",
#              \"replaces\": \"${bundles[index-1]}\" }"
#    fi

    # Add entries to minor channels
    yq -i \
      "(.entries[] | select(.name == \"$channel\").entries) += $object" \
      "$path/olm.template.basic.yaml"
  done

  # Render 'olm.channel' from template
  opm alpha render-template basic \
    --output=yaml \
    "$path/olm.template.basic.yaml" > "$path/olm.channel.yaml"

  # Remove any unnecessary files
  rm "$path/olm.template.basic.yaml"

  success  "Channels"
}

# Generate 'catalog.yaml'
generate_catalog() {
  local version=$1 config=$2 path=$3 temp=$4 bundle=$5
  local supported_versions migrate bundles

  # Read configurations
  package=$(yq -e '.catalog.packageName' "$config")

  # Clear and create required directories
  rm -rf "$temp/${version:?}"
  mkdir -p "$temp/$version" "$path/$version/$package"

  # Prefetch bundles from catalog if catalog.yaml exists
  if [[ -f "$path/$version/$package/catalog.yaml" ]]; then
    yq \
      'select(.schema == "olm.bundle")' \
      "$path/$version/$package/catalog.yaml" \
      > "$temp/olm.bundle.yaml"
  fi

  # Generate 'olm.bundle.yaml' if it doesn't exists
  generate_bundles "$config" "$temp" "$bundle"

  # Fetch supported version from config file
  supported_versions="$(yq -N ".ocp-support.[$version] | join(\"|\")" "$config")"

  # Set flag to use --migrate flag for OCP version < 4.17
  [[ $(printf '%s\n' "$version" "4.17" | sort -V | head -n1) == "4.17" ]] && migrate="true" || migrate="false"

  # Update olm.bundle.yaml with bundles of supported version for OCP support matrix
  yq \
    "select(document_index == (.properties[] |
    select(.type == \"olm.package\").value.version |
    select(test(\"($supported_versions)\") == \"true\") |
    document_index))" \
  "$temp/olm.bundle.yaml" \
  > "$temp/$version/olm.bundle.yaml"

  # Check if there is any bundle to process
  if [[ -z $(yq -N 'select(.schema == "olm.bundle")' "$temp/$version/olm.bundle.yaml") ]]; then
    message "No supported bundles found!"
    return 0
  fi

  # Generate yaml for required OLM schemas
  generate_package "$config" "$temp/$version"
  generate_channels "$config" "$temp/$version"
  generate_deprecations "$config" "$temp/$version"

  opm render \
    --output="yaml" \
    --migrate=$migrate \
    "$temp/$version" \
    > "$path/$version/$package/catalog.yaml"

  # Validate yaml and generate 'catalog.yaml'
  opm validate "$path/$version/$package"

  success "Catalog"
}

# Create catalog from config
generate() {
  local config version versions path temp
  local rebuild="false" bundle=""

  # Parse arguments
  while getopts "b::v:p:t:r:h" option; do
    case "${option}" in
      h) help; exit 0 ;;
      b) bundle="$OPTARG" ;;
      p) path="$OPTARG" ;;
      t) temp="$OPTARG" ;;
      r) rebuild="$OPTARG" ;;
      v) version="$OPTARG" ;;
      \?) echo; error "Invalid option: -$OPTARG" >&2; help; exit 2 ;;
      :) echo; error "Option -$OPTARG requires an argument." >&2; help; exit 2 ;;
    esac
  done
  shift $((OPTIND - 1))

  [[ $# -eq 0 || "$1" == "help" ]] && help && exit 0;

  # Check if config file exists
  config=$1
  if [[ ! -f "$config" ]] ; then
    error "Could not find config file: $config" >&2
    exit 1
  fi

  # Create TEMP directory if doesn't exists
  [[ -z ${temp:-} ]] && temp=$(mktemp -d)

  # Read configurations
  [[ -z ${path:-} ]] && path=$(yq -e ".catalog.directory" "$config")
  if [[ -z ${version:-} ]]; then
    readarray -t versions < <(yq -e ".ocp-support.[] | key" "$config")
  else
    versions=( "$version" )
  fi

  # Create directory if it doesn't exists
  mkdir -p "$path"

  # If "rebuild"" is true, start generation from scratch
  [[ "$rebuild" == "true" ]] && rm -rf "$temp/olm.bundle.yaml"


  # Iterate through OCP versions
  for version in "${versions[@]}"; do
    header "Generating catalog for OpenShift $version"

    # If "rebuild"" is true, start generation from scratch
    [[ "$rebuild" == "true" ]] && rm -rf "$path/${version:?}"

    generate_dockerfile "$version" "$config" "$path"
    generate_catalog "$version" "$config" "$path" "$temp" "$bundle"
    bold "\nCatalog Path: $path/$version \n";
  done
}

generate "$@"

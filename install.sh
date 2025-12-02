#!/bin/sh
set -e

PATH=$PATH:/usr/local/bin

if [ -n "${DEBUG}" ]; then
  set -x
fi

detect_uname() {
  os="$(uname)"
  case "$os" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) echo "Unsupported operating system: $os" 1>&2; return 1 ;;
  esac
  unset os
}

detect_arch() {
  arch="$(uname -m)"
  case "$arch" in
    amd64) echo "amd64" ;;
    x86_64) echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    armv7l|armv8l|arm) echo "arm" ;;
    *) echo "Unsupported processor architecture: $arch" 1>&2; return 1 ;;
  esac
  unset arch
}

# download_k0sctl_url() fetches the k0sctl download url.
download_k0sctl_url() {
  if [ "$arch" = "x64" ];
    then
      arch=amd64
  fi
  echo "https://github.com/k0sproject/k0sctl/releases/download/v$K0SCTL_VERSION/k0sctl-$uname-$arch"
}

# download_mkectl downloads the mkectl binary.
download_mkectl() {
  if [ "$arch" = "x64" ] || [ "$arch" = "amd64" ];
  then
    arch=x86_64
  fi

 REPO_URL="https://github.com/MirantisContainers/mke-release"
 DOWNLOAD_URL="${REPO_URL}/releases/download/${MKECTL_VERSION}/mkectl_${uname}_${arch}.tar.gz"

 # Check if the version exists by checking HTTP status code with redirects enabled
 echo "Checking if the specified version exists..."
 HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -L "$DOWNLOAD_URL")

 # If HTTP status code is not 200 (OK), the file does not exist or there was an error
 if [ "$HTTP_STATUS" -ne 200 ]; then
   echo "Error: The specified version ${MKECTL_VERSION} does not exist or is invalid." >&2
   exit 1
 fi

 # If the version exists, download the file
 echo "Downloading mkectl..."
 curl -s -L -o /tmp/mkectl.tar.gz "$DOWNLOAD_URL"

 # Verify the file is a valid gzip archive
 if [ -s /tmp/mkectl.tar.gz ]; then
   # Extract the downloaded file
   tar -xvzf /tmp/mkectl.tar.gz -C "$installPath" && echo "mkectl is now executable in $installPath" || { echo "Error: Downloaded file is not a valid gzip archive" >&2; exit 1; }
 else
   echo "Error: Downloaded file is empty." >&2
   exit 1
 fi
}

# Download dependencies for MKE version 4.0.0
download_dependencies() {
    printf "\n\n"

    echo "Install k0sctl"
    echo "#########################"

    if [ -z "${K0SCTL_VERSION}" ]; then
      echo "Using default k0sctl version 0.19.4"
      K0SCTL_VERSION=0.19.4
    fi

    k0sctlBinary=k0sctl
    k0sctlDownloadUrl="$(download_k0sctl_url)"


    echo "Downloading k0sctl from URL: $k0sctlDownloadUrl"
    curl -sSLf "$k0sctlDownloadUrl" >"$installPath/$k0sctlBinary"

    sudo chmod 755 "$installPath/$k0sctlBinary"
    echo "k0sctl is now executable in $installPath"
}

# compares versions by ordering them
# Do not use it to compare any semver formats, as it compares release and pre-release versions incorrectly.
# It's used only to compare v4.0.1-* pre-release versions
version_greater_or_equal() { test "$(echo "$@" | tr " " "\n" | sort -rV | head -n 1)" == "$1"; }

# removes leading zero sign from the version part
normalizeSemverZero() {
  next=$(printf %s "${1#0}")
  if [ -z "$next" ]; then
    printf %s "$1"
  fi
  printf %s "$next"
}

# checks if the version contains the specified sign
semverIncludesString() {
  string="$1"
  substring="$2"
  if [ "${string#*"$substring"}" != "$string" ]
  then
    printf "1"
    return 1    # $substring is in $string
  fi
  printf "0"
  return 0    # $substring is not in $string
}

# checks mkectl version and installs required dependencies
installRequiredDependencies() {
  # since this version MKE doesn't need any dependencies
  mke_version_without_dependencies="4.0.1-rc.6"

  # remove any +METADATA if exists
  version=$(printf %s "$1" | cut -d'+' -f 1)
  # remove leading v
  version=$(printf "%s${version#v}")
  version_major=$(normalizeSemverZero "$(printf %s "$version" | cut -d'.' -f 1)")
  version_minor=$(normalizeSemverZero "$(printf %s "$version" | cut -d'.' -f 2)")
  version_patch=$(normalizeSemverZero "$(printf %s "$version" | cut -d'.' -f 3 | cut -d'-' -f 1)")

  # any versions before v4.0.1-rc.6 require to install dependencies
  if [ "$version_major" -le 4 ] && [ "$version_minor" -le 0 ]; then
    if [ "$version_major" -lt 4 ]; then
      echo "MKE version 3 is not supported by this installation method"
      exit 1
    fi
    if [ "$version_patch" -gt 1 ]; then
      return
    fi
    if [ $version_patch == 1 ] && ([ $(semverIncludesString "$version" -) != 1 ] || version_greater_or_equal "$version" "$mke_version_without_dependencies"); then
      return
    fi

    echo "Installing required dependencies..."
    download_dependencies
  fi
}

# checks that sudo and curl system dependencies are installed
check_required_tool() {
  missing_tools=""
  if ! which "curl" > /dev/null; then
    missing_tools="${missing_tools} curl"
  fi

  if ! which "sudo" > /dev/null; then
    missing_tools="${missing_tools} sudo"
  fi

  if [ ! -z "$missing_tools" ]; then
    echo "Please install required tools${missing_tools} and retry installation"
    exit 1
  fi
}

main() {
  check_required_tool

  uname="$(detect_uname)"
  arch="$(detect_arch)"
  installPath=/usr/local/bin

  if [ -z "${MKECTL_VERSION}" ]; then
    # Determine the version
    # Get information about the latest release and pull version from the tag
    MKECTL_VERSION=$(curl -s https://api.github.com/repos/mirantiscontainers/mke-release/releases/latest | grep '"tag_name"' | tr -s ' ' | cut -d ' ' -f 3 | cut -d '"' -f 2)

    if [ -z "${MKECTL_VERSION}" ]; then
      echo "Failed to retrieve the latest release version."
      exit 1
    fi

    echo "MKECTL_VERSION not set, using latest release: ${MKECTL_VERSION}"

  else
    # Make sure it is a valid version
    if ! curl -s https://api.github.com/repos/mirantiscontainers/mke-release/releases?per_page=60 | grep -q "\"tag_name\": \"${MKECTL_VERSION}\""; then
      echo "Error: Invalid version specified: ${MKECTL_VERSION}"
      exit 1
    fi

    echo "Using specified version: ${MKECTL_VERSION}"
  fi

  installRequiredDependencies "$MKECTL_VERSION"

  printf "\n\n"
  echo "Install mkectl"
  echo "#########################"

  printf "\n"

  download_mkectl

}

main "$@"

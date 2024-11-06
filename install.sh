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

# download_kubectl_url() fetches the kubectl download url.
download_kubectl_url() {
  if [ "$arch" = "x64" ];
  then
    arch=amd64
  fi
  echo "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${uname}/${arch}/kubectl"
}

install_kubectl() {
  if [ -z "${KUBECTL_VERSION}" ]; then
    echo "Using default kubectl version v1.30.0"
    KUBECTL_VERSION=v1.30.0
  fi
  kubectlDownloadUrl="$(download_kubectl_url)"
  echo "Downloading kubectl from URL: $kubectlDownloadUrl"
  curl -sSLf "$kubectlDownloadUrl" >$installPath/$kubectlBinary
  sudo chmod 755 "$installPath/$kubectlBinary"
  echo "kubectl is now executable in $installPath"
}

# download_mkectl downloads the mkectl binary.
download_mkectl() {
  if [ "$arch" = "x64" ] || [ "$arch" = "amd64" ];
  then
    arch=x86_64
  fi
  curl --silent -L -s https://s3.us-east-2.amazonaws.com/packages-stage-mirantis.com/${MKECTL_VERSION}/mkectl_${uname}_${arch}.tar.gz | tar -xvzf - -C $installPath
  echo "mkectl is now executable in $installPath"
}

main() {

  uname="$(detect_uname)"
  arch="$(detect_arch)"

  printf "\n\n"

  echo "Step 1/3 : Install k0sctl"
  echo "#########################"

  if [ -z "${K0SCTL_VERSION}" ]; then
    echo "Using default k0sctl version 0.19.0"
    K0SCTL_VERSION=0.19.0
  fi

  k0sctlBinary=k0sctl
  installPath=/usr/local/bin
  k0sctlDownloadUrl="$(download_k0sctl_url)"


  echo "Downloading k0sctl from URL: $k0sctlDownloadUrl"
  curl -sSLf "$k0sctlDownloadUrl" >"$installPath/$k0sctlBinary"

  sudo chmod 755 "$installPath/$k0sctlBinary"
  echo "k0sctl is now executable in $installPath"

  printf "\n\n"
  echo "Step 2/3 : Install kubectl"
  echo "#########################"

  kubectlBinary=kubectl

  if [ -x "$(command -v "$kubectlBinary")" ]; then
    VERSION="$($kubectlBinary version | grep Client | cut -d: -f2)"
    echo "$kubectlBinary version $VERSION already exists."
  else
    install_kubectl
  fi

  printf "\n\n"
  echo "Step 3/3 : Install mkectl"
  echo "#########################"

  if [ -z "${MKECTL_VERSION}" ]; then
    echo "Using default mkectl version v4.0.0-rc.5"
    MKECTL_VERSION=v4.0.0-rc.5
  fi
  printf "\n"


  echo "Downloading mkectl"
  download_mkectl

}

main "$@"

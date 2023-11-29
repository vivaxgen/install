#!/bin/sh

# below is ripped-off from micro.mamba.pm/install.sh

# optional env variables:
# - BASEDIR
# - uMAMBA_ENVNAME

set -eu

# Detect the shell from which the script was called
parent=$(ps -o comm $PPID |tail -1)
parent=${parent#-}  # remove the leading dash that login shells have
case "$parent" in
  # shells supported by `micromamba shell init`
  bash|fish|xonsh|zsh)
    shell=$parent
    ;;
  *)
    # use the login shell (basename of $SHELL) as a fallback
    shell=${SHELL##*/}
    ;;
esac

# Parsing arguments
if [ -t 0 ] && [ -z "${BASEDIR:-}" ]; then
  printf "Base directory? [./vivaxgen-ngspl] "
  read BASEDIR
fi

if [ -t 0 ] && [ -z "${uMAMBA_ENVNAME:-}" ]; then
  printf "micromamba environment name? [ngs-pl] "
  read uMAMBA_ENVNAME
fi

# Fallbacks
BASEDIR="${BASEDIR:-./vivaxgen-ngspl}"
BINDIR="${BASEDIR}/bin"
uMAMBA_ENVNAME=${uMAMBA_ENVNAME:-ngs-pl}
uMAMBA_DIR="${BASEDIR}/opt/umamba"

mkdir -p ${BINDIR}

# Computing artifact location
case "$(uname)" in
  Linux)
    PLATFORM="linux" ;;
  Darwin)
    PLATFORM="osx" ;;
  *NT*)
    PLATFORM="win" ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
  aarch64|ppc64le|arm64)
      ;;  # pass
  *)
    ARCH="64" ;;
esac

case "$PLATFORM-$ARCH" in
  linux-aarch64|linux-ppc64le|linux-64|osx-arm64|osx-64|win-64)
      ;;  # pass
  *)
    echo "Failed to detect your OS" >&2
    exit 1
    ;;
esac

if [ "${VERSION:-}" = "" ]; then
  RELEASE_URL="https://github.com/mamba-org/micromamba-releases/releases/latest/download/micromamba-${PLATFORM}-${ARCH}"
else
  RELEASE_URL="https://github.com/mamba-org/micromamba-releases/releases/download/micromamba-${VERSION}/micromamba-${PLATFORM}-${ARCH}"
fi


# Downloading artifact
mkdir -p "${BINDIR}"
if hash curl >/dev/null 2>&1; then
  curl "${RELEASE_URL}" -o "${BINDIR}/micromamba" -fsSL --compressed ${CURL_OPTS:-}
elif hash wget >/dev/null 2>&1; then
  wget ${WGET_OPTS:-} -qO "${BINDIR}/micromamba" "${RELEASE_URL}"
else
  echo "Neither curl nor wget was found" >&2
  exit 1
fi
chmod +x "${BINDIR}/micromamba"


# this is specific for vivaxGEN ngs-pipeline

echo "Setting up base directory structure at ${BASEDIR}"

export MAMBA_ROOT_PREFIX=${uMAMBA_DIR}
eval "$(${BINDIR}/micromamba shell hook -s posix)"

echo "Creating ${uMAMBA_ENVNAME} environment"
micromamba create -n ${uMAMBA_ENVNAME}

echo "Activating micromamba base environment"
micromamba activate ${uMAMBA_ENVNAME}

if ! [ -x "$(command -v git)" ]; then
  echo "Installing git"
  micromamba -y install git -c conda-forge
fi

if ! [ -x "$(command -v readlink)" ]; then
  echo "Installing coreutils"
  micromamba -y install coreutils -c conda-forge -c defaults
fi

echo "Installing base python 3.12"
micromamba -y install python=3.12 -c conda-forge -c defaults
pip3 install wheel

python3 << EOF

import pathlib, os

path = pathlib.Path("${BINDIR}").resolve()
activation_file = path / "activate_umamba.sh"
with open(activation_file, "w") as out:
  out.write('# -- base activation script from install/base.sh --\n\n')
  out.write('export MAMBA_ROOT_PREFIX=${BASEDIR}/opt/umamba\n')
  out.write(f'PATH={path}:\${{PATH}}\n')
  out.write('eval "\$(\${MAMBA_ROOT_PREFIX}/micromamba shell hook -s posix)"\n\n')
  out.write('micromamba activate ${uMAMBA_ENVNAME}\n\n')

print("\n\nTo activate the micromamba environment, source the activation script:\n")
print("    source " + activation_file.as_posix())
print("")

EOF


# EOF

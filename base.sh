#!/bin/sh

# below is ripped-off from micro.mamba.pm/install.sh

# optional env variables:
# - BASEDIR
# - uMAMBA_ENVNAME

set -eu

# check if we are under CONDA environment, and exit if we are
if [[ ${CONDA_SHLVL:-} -ge 1 ]]; then
  echo "Cannot perform installation while under an active CONDA environment."
  echo "Please deactivate the environment first."
  exit 1
fi


# add helper function
repeat() { while :; do $@ && return; sleep 5; done }

# taken from https://gist.github.com/sj26/88e1c6584397bb7c13bd11108a579746
function retry {
  local retries=$1
  shift

  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1))
    if [ $count -lt $retries ]; then
      echo "Retry $count/$retries exited $exit, retrying in $wait seconds..."
      sleep $wait
    else
      echo "Retry $count/$retries exited $exit, no more retries left."
      return $exit
    fi
  done
  return 0
}

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
  printf "Base directory? [./vvg-base] "
  read BASEDIR
fi

if [ -t 0 ] && [ -z "${uMAMBA_ENVNAME:-}" ]; then
  printf "micromamba environment name? [vvg-base] "
  read uMAMBA_ENVNAME
fi

# Fallbacks
export BASEDIR="${BASEDIR:-./vvg-base}"
BINDIR="${BASEDIR}/bin"
export uMAMBA_ENVNAME=${uMAMBA_ENVNAME:-vvg-base}
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

export OPT_DIR=${BASEDIR}/opt
export APPTAINER_DIR=${BASEDIR}/opt/apptainer
export ENVS_DIR=${BASEDIR}/envs
export ETC_DIR=${BASEDIR}/etc
export BASHRC_DIR=${ETC_DIR}/bashrc.d
export SNAKEMAKEPROFILE_DIR=${ETC_DIR}/snakemake-profiles

mkdir ${OPT_DIR}
mkdir ${APPTAINER_DIR}
mkdir ${ENVS_DIR}
mkdir ${ETC_DIR}
mkdir ${BASHRC_DIR}
mkdir ${SNAKEMAKEPROFILE_DIR}

# check if we are provided with MAMBA_ROOT_PREFIX
if [[ -z ${MAMBA_ROOT_PREFIX:-} ]]; then
  export MAMBA_ROOT_PREFIX=${uMAMBA_DIR}
else
  echo "Using provided MAMBA_ROOT_PREFIX=${MAMBA_ROOT_PREFIX}"
fi

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

if ! [ -x "$(command -v parallel)" ]; then
  echo "Installing parallel"
  micromamba -y install parallel -c conda-forge -c defaults
fi

if ! ([ -x "$(command -v cc)" ] && [ -x "$(command -v ar)" ]); then
  echo "Installing essential c-compiler"
  retry 5 micromamba -y install c-compiler -c conda-forge
fi

if ! ([ -x "$(command -v c++)" ] && [ -x "$(command -v ar)" ]); then
  echo "Installing essential cxx-compiler"
  retry 5 micromamba -y install cxx-compiler -c conda-forge
fi

echo "Installing base python 3.11"
retry 5 micromamba -y install python=3.11 -c conda-forge -c defaults

echo Extracting snakemake cluster profiles
curl -s -L https://raw.github.com/vivaxgen/install/main/snakemake-profiles.tar.gz | tar xvz -C ${ETC_DIR}

if [ -x "$(command -v srun)" ] && [ -x "$(command -v scancel)" ]; then
  echo "Setting up for SLURM"
  ln -sr ${SNAKEMAKEPROFILE_DIR}/slurm/99-snakemake-profile ${BASHRC_DIR}/
elif [ -x "$(command -v qrun)" ] && [ -x "$(command -v qdel)" ]; then
  echo "Setting up for PBS/Torque"
  ln -sr ${SNAKEMAKEPROFILE_DIR}/slurm/99-snakemake-profile ${BASHRC_DIR}/
else
  echo "No batch/job scheduler found"
fi

# install vvg-base repo
echo "Cloning vivaxGEN vvg-base repository"
git clone https://github.com/vivaxgen/vvg-base.git ${ENVS_DIR}/vvg-base
ln -sr ${ENVS_DIR}/vvg-base/etc/bashrc ${ETC_DIR}/bashrc

# prepare activation file
echo "Preparing activation source file"
${ENVS_DIR}/vvg-base/bin/generate-activation-script.py

# re-activate environment
micromamba deactivate
source ${BINDIR}/activate

echo
echo "To activate the micromamba environment, either run the activation script"
echo "to get a new shell:"
echo
echo "    ${BINDIR}/activate"
echo
echo "or source the activation script (eg. inside another script):"
echo
echo "    source ${BINDIR}/activate"
echo

# EOF

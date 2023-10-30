#!/bin/sh

# below is ripped-off from micro.mamba.pm/install.sh

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
if [ -t 0 ] ; then
  printf "Pipeline folder? [./ampseq-pipeline] "
  read PIPELINE_FOLDER
fi

# Fallbacks
PIPELINE_FOLDER="${PIPELINE_FOLDER:-./ampseq-pipeline}"
BIN_FOLDER="${PIPELINE_FOLDER}/opt/umamba"
INIT_YES="${INIT_YES:-no}"
CONDA_FORGE_YES="${CONDA_FORGE_YES:-no}"

# Prefix location is relevant only if we want to call `micromamba shell init`
case "$INIT_YES" in
  y|Y|yes)
    if [ -t 0 ]; then
      printf "Prefix location? [~/micromamba] "
      read PREFIX_LOCATION
    fi
    ;;
esac
PREFIX_LOCATION="${PREFIX_LOCATION:-${HOME}/micromamba}"

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
mkdir -p "${BIN_FOLDER}"
if hash curl >/dev/null 2>&1; then
  curl "${RELEASE_URL}" -o "${BIN_FOLDER}/micromamba" -fsSL --compressed ${CURL_OPTS:-}
elif hash wget >/dev/null 2>&1; then
  wget ${WGET_OPTS:-} -qO "${BIN_FOLDER}/micromamba" "${RELEASE_URL}"
else
  echo "Neither curl nor wget was found" >&2
  exit 1
fi
chmod +x "${BIN_FOLDER}/micromamba"


# Initializing shell
case "$INIT_YES" in
  y|Y|yes)
    case $("${BIN_FOLDER}/micromamba" --version) in
      1.*|0.*)
        shell_arg=-s
        prefix_arg=-p
        ;;
      *)
        shell_arg=--shell
        prefix_arg=--root-prefix
        ;;
    esac
    "${BIN_FOLDER}/micromamba" shell init $shell_arg "$shell" $prefix_arg "$PREFIX_LOCATION"

    echo "Please restart your shell to activate micromamba or run the following:\n"
    echo "  source ~/.bashrc (or ~/.zshrc, ~/.xonshrc, ~/.config/fish/config.fish, ...)"
    ;;
  *)
    echo "You can initialize your shell later by running:"
    echo "  micromamba shell init"
    ;;
esac


# Initializing conda-forge
case "$CONDA_FORGE_YES" in
  y|Y|yes)
    "${BIN_FOLDER}/micromamba" config append channels conda-forge
    "${BIN_FOLDER}/micromamba" config append channels bioconda
    "${BIN_FOLDER}/micromamba" config append channels defaults
    "${BIN_FOLDER}/micromamba" config set channel_priority strict
    ;;
esac

# this is specific for ampseq-pipeline

echo "Setting up for ampseq-pipeline"

export MAMBA_ROOT_PREFIX=${BIN_FOLDER}
eval "$(${BIN_FOLDER}/micromamba shell hook -s posix)"

echo "Creating ampseq-pl environment"
micromamba create -n ampseq-pl

echo "Activating micromamba base environment"
micromamba activate ampseq-pl

#echo "Installing git"
#micromamba -y install git -c conda-forge

echo "Installing latest htslib tools"
micromamba -y install "bcftools>=1.18" "samtools>=1.18" -c conda-forge -c bioconda -c defaults

echo "installing minimap"
micromamba -y install minimap2 -c conda-forge -c bioconda -c defaults

echo "Installing freebayes"
micromamba -y install freebayes -c conda-forge -c bioconda -c defaults

echo "Install vcftools"
micromamba -y install vcftools -c conda-forge -c bioconda

echo "Installing chopper"
micromamba -y install chopper -c conda-forge -c bioconda -c defaults

echo "Installing snpEff"
micromamba -y install snpeff -c conda-forge -c bioconda -c defaults

if ! [ -x "$(command -v git)" ]; then
  echo "Installing git"
  micromamba -y install git -c conda-forge
fi

if ! [ -x "$(command -v readlink)" ]; then
  echo "Installing coreutils"
  micromamba -y install coreutils -c conda-forge -c defaults
fi

echo "Installing python 3.11 and its modules"
micromamba -y install python=3.11 -c conda-forge -c defaults
pip3 install  wheel
pip3 install snakemake cyvcf2 NanoPlot



# prepare activation scripts
mkdir ${PIPELINE_FOLDER}/bin

python3 << EOF

import pathlib

path = pathlib.Path("${PIPELINE_FOLDER}").resolve()
activation_file = path / "bin/activate.sh"
with open(activation_file, "w") as out:
  out.write("# ampseq-pipeline activation script\n\n")
  out.write("# set base pipeline directory\n")
  out.write('export AMPSEQ_PIPELINE_BASEDIR=' + path.as_posix() + '\n\n')
  out.write('export MAMBA_ROOT_PREFIX=\${AMPSEQ_PIPELINE_BASEDIR}/opt/umamba\n')
  out.write('eval "\$(\${MAMBA_ROOT_PREFIX}/micromamba shell hook -s posix)"\n\n')
  out.write('micromamba activate ampseq-pl\n')

print("\n\nTo activate ampseq-pipeline environment, source the activation script:\n")
print("    source " + activation_file.as_posix())
print("")

EOF


# EOF

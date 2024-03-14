#!/bin/sh

# below is ripped-off from micro.mamba.pm/install.sh

# optional env variables:
# - BASEDIR
# - uMAMBA_ENVNAME

set -eu

# add helper function
repeat() { while :; do $@ && return; sleep 5; done }

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
BASEDIR="${BASEDIR:-./vvg-base}"
BINDIR="${BASEDIR}/bin"
uMAMBA_ENVNAME=${uMAMBA_ENVNAME:-vvg-base}
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

echo "Preparing update script"
cat > ${BINDIR}/update-pipeline.sh << EOF
#!/usr/bin/env bash

echo "Updating all sofware packages under \$VVG_BASEDIR/envs..."
for p in \$VVG_BASEDIR/envs/*; do
    if [ -d "\$p" ]; then
        echo "Updating \${p}"
        (cd "\$p"; git pull)
    fi
done
unset p

echo "Updating finished."

EOF
chmod a+x ${BINDIR}/update-pipeline.sh

echo "Preparing micromamba environment export script"
cat > ${BINDIR}/export-environment.sh << EOF
#!/usr/bin/env bash

echo "Exporting environment to \$VVG_BASEDIR/etc/env.yaml"
micromamba env export > \$VVG_BASEDIR/etc/env.yaml

EOF
chmod a+x ${BINDIR}/export-environment.sh

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

if ! [ -x "$(command -v parallel)" ]; then
  echo "Installing parallel"
  micromamba -y install parallel -c conda-forge -c defaults
fi

if ! ([ -x "$(command -v cc)" ] && [ -x "$(command -v ar)" ]); then
  echo "Installing essential c-compiler"
  micromamba -y install c-compiler -c conda-forge
fi

if ! ([ -x "$(command -v c++)" ] && [ -x "$(command -v ar)" ]); then
  echo "Installing essential cxx-compiler"
  micromamba -y install cxx-compiler -c conda-forge
fi

echo "Installing base python 3.11"
micromamba -y install python=3.11 -c conda-forge -c defaults
pip3 install wheel
#pip3 install 'pulp<2.8'
#pip3 install 'snakemake<8'

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

echo "Preparing activation source file"
python3 << EOF

import pathlib, os

BASEDIR = pathlib.Path("${BASEDIR}").resolve()
uMAMBA_ENVNAME = "${uMAMBA_ENVNAME}"
bashrc_file = BASEDIR / 'etc' / "bashrc"

bashrc_content = f"""

# -- base activation source script from install/base.sh --
# -- [https://github.com/vivaxgen/install] --

export VVG_BASEDIR={BASEDIR}
PATH=\${{VVG_BASEDIR}}/bin:\${{PATH}}
export MAMBA_ROOT_PREFIX=\${{VVG_BASEDIR}}/opt/umamba
export APPTAINER_DIR=\${{VVG_BASEDIR}}/opt/apptainer
eval "\$(micromamba shell hook -s posix)"
micromamba activate {uMAMBA_ENVNAME}

for rc in \${{VVG_BASEDIR}}/etc/bashrc.d/*; do
    if [ -f "\$rc" ]; then
        . "\$rc"
    fi
done
unset rc


"""

with open(bashrc_file, "w") as out:
  out.write(bashrc_content)

activation_file = BASEDIR / 'bin' / 'activate'

activation_content = f"""
#!/usr/bin/env bash

BASHRC={bashrc_file.as_posix()}

if [[ "\${{BASH_SOURCE[0]}}" == "\${{0}}" ]]; then
  set -o errexit
  set -o pipefail
  set -o nounset

  bash --init-file <(echo ". /etc/profile; . ~/.bashrc; . \${{BASHRC}}")

else

  . \${{BASHRC}}

fi

"""

with open(activation_file, "w") as out:
  out.write(activation_content)


print("\n\nTo activate the micromamba environment, either run the activation script")
print("to get a new shell:\n")
print("    " + activation_file.as_posix())
print("\nor source the activation script (eg. inside another script):\n")
print("    source " + activation_file.as_posix())
print("")

EOF
chmod a+x ${BINDIR}/activate

# EOF

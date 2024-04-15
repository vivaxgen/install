#!/usr/bin/bash

# installation script for G6PD pipeline

# optional variable:
# - BASEDIR
# - OMIT

set -eu

# run the base.sh
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
  printf "Pipeline base directory? [./ont-g6pd-pipeline] "
  read BASEDIR
fi

# default value
BASEDIR="${BASEDIR:-./ont-g6pd-pipeline}"

uMAMBA_ENVNAME='ONT-G6PD'
OMIT='GATK4'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/ngs-pl.sh)

echo Installing apptainer
micromamba -y install apptainer -c conda-forge -c bioconda
micromamba -y install squashfuse -c conda-forge

echo "Cloning G6PD pipeline"
git clone https://github.com/vivaxgen/G6PD_MinION.git ${ENVS_DIR}/G6PD-pipeline

#echo "source \${VVG_BASEDIR}/env/G6PD-pipeline/activate.sh" >> ${BASEDIR}/bin/activate.sh
ln -sr ${ENVS_DIR}/G6PD-pipeline/etc/bashrc.d/50-g6pd-pipeline ${BASHRC_DIR}/

echo "Reloading source files"
reload_vvg_profiles

# install Clair3 using apptainer/singularity image, since the conda-based
# installation requires python version 3.9.0, conflicting with our python 3.11
echo "Downloading Clair3 apptainer/singularity image"
retry 5 apptainer pull ${APPTAINER_DIR}/clair3.sif docker://hkubal/clair3:latest

echo "Indexing reference sequence"
ngs-pl index-reference

echo
echo "G6PD pipeline has been successfully installed."
echo "To activate the G6PD pipeline environment, either run the activation script"
echo "to get a new shell:"
echo
echo "    `realpath ${BINDIR}/activate`"
echo
echo "or source the activation script (eg. inside another script):"
echo
echo "    source `realpath ${BINDIR}/activate`"
echo

# EOF

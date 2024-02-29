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

uMAMBA_ENVNAME='ngs-pl'
OMIT='GATK4'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/ngs-pl.sh)

echo Installing apptainer
micromamba -y install apptainer -c conda-forge -c bioconda

echo Cloning G6PD pipeline
git clone https://github.com/vivaxgen/G6PD_MinION.git ${ENVS_DIR}/G6PD-pipeline

#echo "source \${VVG_BASEDIR}/env/G6PD-pipeline/activate.sh" >> ${BASEDIR}/bin/activate.sh
ln -sr ${ENVS_DIR}/G6PD-pipeline/activate.sh ${BASHRC_DIR}/50-g6pd-pipeline

echo Activating enviroment
# prevent unbound variable for PYTHONPATH and NGS_PIPELINE_CMD_MODS
export PYTHONPATH=""
export NGS_PIPELINE_CMD_MODS=""
source ${BASEDIR}/bin/activate.sh

# install Clair3 using apptainer/singularity image, since the conda-based
# installation requires python version 3.9.0, conflicting with our python 3.11
echo Downloading Clair3 apptainer/singularity image
apptainer pull ${APPTAINER_DIR}clair3.sif docker://hkubal/clair3:latest

echo Indexing reference sequence
ngs-pl index-reference

echo "G6PD pipeline has been successfully installed."
echo "Please use the following command to source the activation script and activate the environment:"
echo ""
echo "    source ${BASEDIR}/bin/activate.sh"
echo ""

# EOF

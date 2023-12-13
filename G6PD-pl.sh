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
echo "export APPTAINER_DIR=\${VVG_BASEDIR}/opt/apptainer" >> ${BASEDIR}/bin/activate.sh
mkdir -p ${BASEDIR}/opt/apptainer

echo Cloning G6PD pipeline
git clone https://github.com/vivaxgen/G6PD_MinION.git ${BASEDIR}/env/G6PD-pipeline

echo "source \${VVG_BASEDIR}/env/G6PD-pipeline/activate.sh" >> ${BASEDIR}/bin/activate.sh

echo Activating enviroment
# prevent unbound variable for PYTHONPATH and NGS_PIPELINE_CMD_MODS
export PYTHONPATH=""
export NGS_PIPELINE_CMD_MODS=""
source ${BASEDIR}/bin/activate.sh

# echo Downloading Clair3 apptainer/singularity image
# do something here

echo Indexing reference sequence
ngs-pl index-reference


echo "G6PD pipeline has been successfully installed. Please source the activation file to start using it:"
echo ""
echo "    source ${BASEDIR}/bin/activate.sh"
echo ""

# EOF

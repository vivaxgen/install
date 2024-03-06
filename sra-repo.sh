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
  printf "Pipeline base directory? [./SRA] "
  read BASEDIR
fi

# default value
BASEDIR="${BASEDIR:-./SRA}"

uMAMBA_ENVNAME='SRA'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/base.sh)

echo "Installing latest htslib tools"
# samtools is needed to convert CRAM/BAM to FASTQ files
micromamba -y install "samtools>=1.18" -c conda-forge -c bioconda -c defaults

echo Installing NCBI SRA Toolkit
micromamba -y install sra-tools -c conda-forge -c bioconda

echo "installing required Python modules"
pip3 install pycurl
pip3 install requests
pip3 install rich
pip3 install IPython 
pip3 install argcomplete
pip3 install flufl.lock
pip3 install pyyaml

echo Cloning vivaxGEN SRA-Repo
git clone https://github.com/vivaxgen/sra-repo.git ${ENVS_DIR}/sra-repo
ln -sr ${ENVS_DIR}/sra-repo/bin/activate.sh ${BASHRC_DIR}/50-sra-repo

echo preparing directories
mkdir -p ${BASEDIR}/store
mkdir -p ${BASEDIR}/store/.lock
touch ${BASEDIR}/store/.sra-repo-db
mkdir -p ${BASEDIR}/tmp
mkdir -p ${BASEDIR}/cache

echo "vivaxGEN SRA-Repo has been successfully installed. Read the docs for usage."
echo "Please source the activation file to start using it:"
echo ""
echo "    source" `readlink -e ${BASEDIR}/bin/activate.sh`
echo ""

# EOF

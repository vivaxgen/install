#!/usr/bin/bash

# installation script for vivaxgen ngs-pipeline [https://github.com/vivaxgen/ngs-pipeline]

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
  printf "Pipeline base directory? [./vvg-ngspl] "
  read BASEDIR
fi

# default value
BASEDIR="${BASEDIR:-./vvg-ngspl}"

uMAMBA_ENVNAME='ngs-pl'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/base.sh)

OMIT="${OMIT:-}"

if ! [[ "$OMIT" =~ GATK ]]; then
  echo "Installing the latest GATK"
  micromamba -y install GATK4 -c conda-forge -c bioconda
fi

echo "Installing latest htslib tools"
micromamba -y install "bcftools>=1.18" "samtools>=1.18" -c conda-forge -c bioconda -c defaults

echo "Installing latest fastp"
micromamba -y install fastp -c conda-forge -c bioconda

echo "Installing latest bwa-mem2"
micromamba -y install bwa-mem2 -c conda-forge -c bioconda

echo "installing minimap2"
micromamba -y install minimap2 -c conda-forge -c bioconda -c defaults

echo "Installing freebayes"
micromamba -y install freebayes=1.3.6 -c conda-forge -c bioconda -c defaults

echo "Install vcftools"
micromamba -y install vcftools -c conda-forge -c bioconda

echo "Installing chopper"
micromamba -y install chopper -c conda-forge -c bioconda -c defaults

echo "Installing snpEff"
micromamba -y install snpeff -c conda-forge -c bioconda -c defaults

echo "installing required Python modules"
pip3 install cyvcf2
pip3 install pysam
pip3 install pandas
pip3 install Pillow
pip3 install IPython
pip3 install matplotlib
pip3 install pycairo
pip3 install NanoPlot
pip3 install argcomplete

echo Cloning vivaxGEN ngs-pipeline
git clone https://github.com/vivaxgen/ngs-pipeline.git ${ENVS_DIR}/ngs-pipeline
ln -sr ${ENVS_DIR}/ngs-pipeline/bin/activate.sh ${BASHRC_DIR}/10-ngs-pipeline

echo "vivaxGEN ngs-pipeline has been successfully installed. "
echo "Please read the docs for further setup."
echo "The base installation directory (VVG_BASEDIR) is:"
echo
echo ${BASEDIR}
echo

# EOF

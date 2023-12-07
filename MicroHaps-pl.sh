#!/usr/bin/bash

# installation script for vivaxgen MicroHaps pipeline [https://github.com/vivaxgen/MicroHaps]

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
  printf "Pipeline base directory? [./vvg-MicroHaps] "
  read BASEDIR
fi

# default value
BASEDIR="${BASEDIR:-./vvg-MicroHaps}"

uMAMBA_ENVNAME='MicroHaps'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/base.sh)

OMIT="${OMIT:-}"

echo "Installing latest htslib tools"
micromamba -y install "bcftools>=1.18" "samtools>=1.18" -c conda-forge -c bioconda -c defaults

echo "Installing latest bedtools"
micromamba -y install bedtools -c conda-forge -c bioconda -c defaults

echo "Installing python version 3.8"
micromamba -y install "python=3.8" -c conda-forge -c bioconda -c defaults

echo "Installing latest fastp"
micromamba -y install fastp -c conda-forge -c bioconda

echo "Installing latest bwa"
micromamba -y install bwa -c conda-forge -c bioconda -c defaults

echo "installing minimap2"
micromamba -y install minimap2 -c conda-forge -c bioconda -c defaults

echo "installing parallel"
micromamba -y install parallel -c conda-forge -c bioconda -c defaults

echo "Installing datamash"
micromamba -y install datamash -c conda-forge -c bioconda -c defaults

echo "Installing delly"
micromamba -y install delly -c conda-forge -c bioconda -c defaults

echo "Installing tqdm"
micromamba -y install tqdm -c conda-forge -c bioconda -c defaults

echo "Installing freebayes"
micromamba -y install freebayes -c conda-forge -c bioconda -c defaults

echo "Installing trimmomatic"
micromamba -y install trimmomatic -c conda-forge -c bioconda -c defaults

echo "Installing biopython"
micromamba -y install biopython -c conda-forge -c bioconda -c defaults

echo "Installing chopper"
micromamba -y install chopper -c conda-forge -c bioconda -c defaults

echo "Installing snpEff"
micromamba -y install snpeff -c conda-forge -c bioconda -c defaults

echo "Installing iqtree"
micromamba -y install iqtree -c conda-forge -c bioconda -c defaults

echo "Installing fastqc"
micromamba -y install fastqc -c conda-forge -c bioconda -c defaults

echo "Installing multiqc"
micromamba -y install multiqc -c conda-forge -c bioconda -c defaults

echo "Installing mosdepth"
micromamba -y install mosdepth -c conda-forge -c bioconda -c defaults

echo "Installing samclip"
micromamba -y install samclip -c conda-forge -c bioconda -c defaults

echo "Installing sambamba"
micromamba -y install sambamba -c conda-forge -c bioconda -c defaults

echo "Installing cutadapt"
micromamba -y install cutadapt -c conda-forge -c bioconda -c defaults

echo "Installing muscle version v3.8.1551"
micromamba -y install "muscle=3.8.1551" -c conda-forge -c bioconda -c defaults

echo "Installing required R packages"
micromamba -y install r-ggplot2 r-BiocManager r-RCurl r-argparse r-data.table r-seqinr r-doMC -c conda-forge -c bioconda -c defaults

# Install additional R packages
R --no-save << EOF
BiocManager::install("GenomeInfoDb")
BiocManager::install("GenomicRanges")
BiocManager::install("Biostrings")
BiocManager::install("Rsamtools")
BiocManager::install("SummarizedExperiment")
BiocManager::install("GenomicAlignments")
BiocManager::install("ShortRead")
BiocManager::install("dada2")
BiocManager::install("limma")
EOF

if ! [[ "$OMIT" =~ GATK ]]; then
  echo "Installing the latest GATK"
  micromamba -y install GATK4 -c conda-forge -c bioconda
fi

echo "installing required Python modules"
pip3 install snakemake
pip3 install cyvcf2
pip3 install pysam
pip3 install pandas
pip3 install Pillow
pip3 install IPython 
pip3 install matplotlib
#pip3 install NanoPlot
pip3 install argcomplete

# to use latest of all python-related stuff, uncomment below and remove the conda parts
# pip3 install biopython
# pip3 install cutadapt
# pip3 install multiqc
# pip3 install tqdm

# prepare MicroHaps pipeline environment
mkdir -p ${BASEDIR}/env

echo Cloning vivaxGEN MicroHaps pipeline
git clone https://github.com/vivaxgen/MicroHaps.git ${BASEDIR}/env/MicroHaps

echo "source \${VVG_BASEDIR}/env/MicroHaps/activate.sh" >> ${BASEDIR}/bin/activate.sh

echo ""
echo "vivaxGEN MicroHaps pipeline has been successfully installed. Please source the activation file to start using it:"
echo ""
echo "    source ${BASEDIR}/bin/activate.sh"
echo ""
# EOF

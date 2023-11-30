#!/bin/sh

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

uMAMBA_ENVNAME='ngs-pl'
OMIT='GATK4'
source <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/ngs-pl.sh)

echo Cloning G6PD pipeline
git clone https://github.com/mkleinecke/G6PD_pipeline.git ${VVG_BASEDIR}/env/G6PD-pipeline

echo "source \${VVG_BASEDIR}/env/G6PD-pipeline/bin/activate.sh" >> ${VVG_BASEDIR}/bin/activate.sh

echo "G6PD pipeline has been successfully installed. Please source the activation file to start using it:"
echo ""
echo "    source ${VVG_BASEDIR}/bin/activate.sh"
echo ""

# EOF

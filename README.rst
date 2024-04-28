vivaxGEN Installation Script Collection
=======================================

Quick Start
-----------

For vivaxGEN `ngs-pipeline <https://github.com/vivaxgen/ngs-pipeline>`_,
install with the following command::

    "${SHELL}" <(curl -L https://raw.githubusercontent.com/vivaxgen/ngs-pipeline/main/install.sh)

For `SRA Repo <https://github.com/vivaxgen/sra-repo>`_, install with the
following command::

    "${SHELL}" <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/sra-repo.sh)

For `G6PD amplicon sequencing pipeline <https://github.com/vivaxgen/G6PD_MinION>`_,
install with the following command::

    "${SHELL}" <(curl -L https://raw.githubusercontent.com/vivaxgen/G6PD_MinION/main/install.sh)

For vivaxGEN `MicroHaps sequencing pipeline <https://github.com/vivaxgen/MicroHaps>`_,
install with the following command::

    "${SHELL}" <(curl -L https://raw.githubusercontent.com/vivaxgen/install/main/MicroHaps-pl.sh)

The vivaxGEN `Base  Installation Utility <https://github.com/vivaxgen/vvg-base>`_
can be installed using the following command::

    "${SHELL}" <(curl -L https://raw.githubusercontent.com/vivaxgen/vvg-base/main/install.sh)


Quick Overview
--------------

This repo contains install scripts (or links to install scripts) for software
packages (such as various pipelines) that use micromamba to provide all binary
dependencies.
No configuration or setting files will be left on the home directory of the
users who execute the install scripts (apart from download cache of micromamba
in ~/.cache directory that can be removed manually, and addition of the
environment directory at ~/.conda/environment.txt, if ~/.conda/environment.txt
is already existed, which can also be deleted manually).

The installed system using these install scripts can be uninstalled by removing
the installation directory.

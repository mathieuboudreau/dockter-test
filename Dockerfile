FROM debian:stretch

ARG DEBIAN_FRONTEND=noninteractive

#----------------------------------------------------------
# Install common dependencies and create default entrypoint
#----------------------------------------------------------
ENV LANG="en_US.UTF-8" \
    LC_ALL="C.UTF-8" \
    ND_ENTRYPOINT="/neurodocker/startup.sh"
RUN apt-get update -qq && apt-get install -yq --no-install-recommends  \
    	apt-utils bzip2 ca-certificates curl locales unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && localedef --force --inputfile=en_US --charmap=UTF-8 C.UTF-8 \
    && chmod 777 /opt && chmod a+s /opt \
    && mkdir -p /neurodocker \
    && if [ ! -f "$ND_ENTRYPOINT" ]; then \
         echo '#!/usr/bin/env bash' >> $ND_ENTRYPOINT \
         && echo 'set +x' >> $ND_ENTRYPOINT \
         && echo 'if [ -z "$*" ]; then /usr/bin/env bash; else $*; fi' >> $ND_ENTRYPOINT; \
       fi \
    && chmod -R 777 /neurodocker && chmod a+s /neurodocker
ENTRYPOINT ["/neurodocker/startup.sh"]

#-----------------------------------------------------------
# Install FSL v5.0.10
# FSL is non-free. If you are considering commerical use
# of this Docker image, please consult the relevant license:
# https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence
#-----------------------------------------------------------
RUN apt-get update -qq && apt-get install -yq --no-install-recommends bc dc libfontconfig1 libfreetype6 libgl1-mesa-dev libglu1-mesa-dev libgomp1 libice6 libmng1 libxcursor1 libxft2 libxinerama1 libxrandr2 libxrender1 libxt6 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && echo "Downloading FSL ..." \
    && curl -sSL --retry 5 https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.10-centos6_64.tar.gz \
    | tar zx -C /opt \
    && /bin/bash /opt/fsl/etc/fslconf/fslpython_install.sh -q -f /opt/fsl \
    && sed -i '$iecho Some packages in this Docker container are non-free' $ND_ENTRYPOINT \
    && sed -i '$iecho If you are considering commercial use of this container, please consult the relevant license:' $ND_ENTRYPOINT \
    && sed -i '$iecho https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/Licence' $ND_ENTRYPOINT \
    && sed -i '$isource $FSLDIR/etc/fslconf/fsl.sh' $ND_ENTRYPOINT
ENV FSLDIR=/opt/fsl \
    PATH=/opt/fsl/bin:$PATH

#------------------
# Install Miniconda
#------------------
ENV CONDA_DIR=/opt/conda \
    PATH=/opt/conda/bin:$PATH
RUN echo "Downloading Miniconda installer ..." \
    && miniconda_installer=/tmp/miniconda.sh \
    && curl -sSL --retry 5 -o $miniconda_installer https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && /bin/bash $miniconda_installer -b -p $CONDA_DIR \
    && rm -f $miniconda_installer \
    && conda config --system --prepend channels conda-forge \
    && conda config --system --set auto_update_conda false \
    && conda config --system --set show_channel_urls true \
    && conda clean -tipsy && sync

#-------------------------
# Create conda environment
#-------------------------
RUN conda create -y -q --name neuro python=3.6 \
                                    traits \
    && sync && conda clean -tipsy && sync \
    && /bin/bash -c "source activate neuro \
      && pip install -q --no-cache-dir nipype" \
    && sync

#--------------------------------------
# Save container specifications to JSON
#--------------------------------------
RUN echo '{ \
    \n  "pkg_manager": "apt", \
    \n  "check_urls": true, \
    \n  "instructions": [ \
    \n    [ \
    \n      "base", \
    \n      "debian:stretch" \
    \n    ], \
    \n    [ \
    \n      "fsl", \
    \n      { \
    \n        "version": "5.0.10" \
    \n      } \
    \n    ], \
    \n    [ \
    \n      "miniconda", \
    \n      { \
    \n        "env_name": "neuro", \
    \n        "conda_install": "python=3.6 traits", \
    \n        "pip_install": "nipype" \
    \n      } \
    \n    ] \
    \n  ], \
    \n  "generation_timestamp": "2020-06-08 23:52:09", \
    \n  "neurodocker_version": "0.3.2" \
    \n}' > /neurodocker/neurodocker_specs.json

RUN pip install --no-cache-dir notebook==5.*

# create user with a home directory
ARG NB_USER
ARG NB_UID
ENV USER ${NB_USER}
ENV HOME /home/${NB_USER}

RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}
WORKDIR ${HOME}
USER ${USER}

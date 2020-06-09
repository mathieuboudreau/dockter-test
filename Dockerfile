FROM ubuntu:xenial

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential=12.1ubuntu2 \
        emacs \
        git \
        inkscape \
        jed \
        libsm6 \
        libxext-dev \
        libxrender1 \
        lmodern \
        netcat \
        unzip \
        nano \
        curl \
        wget \
        gfortran \
        cmake \
        bsdtar  \
        rsync \
        imagemagick \
        gnuplot-x11 \
        libopenblas-base \
        python3-dev \
        python3-pip \
        ttf-dejavu \
        wget \
        jq \
        vim && \
    apt-get clean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# install the notebook package
RUN pip3 install --no-cache --upgrade pip && \
    pip3 install --no-cache setuptools && \
    pip3 install --no-cache notebook

#install neurodebian
RUN wget -O- http://neuro.debian.net/lists/xenial.us-tn.full | tee /etc/apt/sources.list.d/neurodebian.sources.list
RUN apt-key adv --recv-keys --keyserver hkp://pool.sks-keyservers.net:80 0xA5D32F012649A5A9

#install fsl
RUN apt-get update && apt-get install -y fsl python-numpy

ENV FSLDIR=/usr/share/fsl/5.0
ENV PATH=$PATH:$FSLDIR/bin
ENV LD_LIBRARY_PATH=/usr/lib/fsl/5.0:/usr/share/fsl/5.0/bin

#simulate . ${FSLDIR}/etc/fslconf/fsl.sh
ENV FSLBROWSER=/etc/alternatives/x-www-browser
ENV FSLCLUSTER_MAILOPTS=n
ENV FSLLOCKDIR=
ENV FSLMACHINELIST=
ENV FSLMULTIFILEQUIT=TRUE
ENV FSLOUTPUTTYPE=NIFTI_GZ
ENV FSLREMOTECALL=
ENV FSLTCLSH=/usr/bin/tclsh
ENV FSLWISH=/usr/bin/wish
ENV POSSUMDIR=/usr/share/fsl/5.0

#make it work under singularity
RUN ldconfig && mkdir -p /N/u /N/home /N/dc2 /N/soft

#https://wiki.ubuntu.com/DashAsBinSh
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

ARG NPROC=1

WORKDIR /tmp
RUN curl -fsSLO https://raw.githubusercontent.com/cms-sw/cms-docker/master/slc6/RPM-GPG-KEY-cern \
    && rpm --import RPM-GPG-KEY-cern \
    && curl -fsSL -o /etc/yum.repos.d/slc6-scl.repo http://linuxsoft.cern.ch/cern/scl/slc6-scl.repo \
    && yum install -y -q \
          curl \
          devtoolset-3-gcc-c++ \
          git \
          make \
          zlib-devel \
    && yum clean packages \
    && rm -rf /var/cache/yum/* && rm -rf /tmp/* \
    && curl -fsSL https://cmake.org/files/v3.12/cmake-3.12.2.tar.gz | tar -xz \
    && cd cmake-3.12.2 \
    && source /opt/rh/devtoolset-3/enable \
    && printf "\n\n+++++++++++++++++++++++++++++++++\n\
BUILDING CMAKE WITH $NPROC PROCESS(ES)\n\
+++++++++++++++++++++++++++++++++\n\n" \
    && ./bootstrap --parallel=$NPROC -- -DCMAKE_BUILD_TYPE:STRING=Release \
    && make -j$NPROC \
    && make install \
    && cd .. \
    && rm -rf *

ARG ants_version

ENV ANTS_VERSION=$ants_version
WORKDIR /src
RUN if [ -z "$ants_version" ]; then \
        echo "ERROR: ants_version not defined" && exit 1; \
    fi \
    && echo "Compiling ANTs version $ants_version" \
    && git clone git://github.com/stnava/ANTs.git ants \
    && cd ants \
    && git fetch origin --tags \
    && git checkout $ants_version \
    && mkdir build \
    && cd build \
    && source /opt/rh/devtoolset-3/enable \
    && printf "\n\n++++++++++++++++++++++++++++++++\n\
BUILDING ANTS WITH $NPROC PROCESS(ES)\n\
++++++++++++++++++++++++++++++++\n\n" \
    && cmake -DCMAKE_INSTALL_PREFIX="/opt/ants" .. \
    && make -j$NPROC \
    && if [ -d /src/ants/build/ANTS-build ]; then \
            \
            cd /src/ants/build/ANTS-build \
            && make install; \
       else \
            \
            mkdir -p /opt/ants \
            && mv bin/* /opt/ants \
            && mv ../Scripts/* /opt/ants; \
       fi

COPY --from=builder /opt/ants /opt/ants

ENV ANTSPATH=/opt/ants/ \
    PATH=/opt/ants:/opt/ants/bin:$PATH

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

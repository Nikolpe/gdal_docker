# Ubuntu 18.04 Bionic Beaver
FROM ubuntu:bionic

MAINTAINER Nikolaj Persson <niper@sdfe.dk>

ENV ORACLE_HOME=/home/niper/software/oracle/instantclient_12_2
ENV PATH=$PATH:$ORACLE_HOME
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME
ENV ROOTDIR /usr/local/
ENV GDAL_VERSION 2.3.2
ENV OPENJPEG_VERSION 2.3.0

# Load assets
WORKDIR $ROOTDIR/
# Adding zip files for instant client
ADD instantclient-basic-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/
ADD instantclient-sqlplus-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/
ADD instantclient-sdk-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/
# Use wget or curl instead (docker best practice)
ADD http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz $ROOTDIR/src/
ADD https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz $ROOTDIR/src/openjpeg-${OPENJPEG_VERSION}.tar.gz

# Install basic dependencies
RUN apt-get update -y && apt-get install -y \
    libaio1 \
    unzip \
    software-properties-common \
    build-essential \
    python-dev \
    python3-dev \
    python-numpy \
    python3-numpy \
    libspatialite-dev \
    sqlite3 \
    libpq-dev \
    libcurl4-gnutls-dev \
    libproj-dev \
    libxml2-dev \
    libgeos-dev \
    libnetcdf-dev \
    libpoppler-dev \
    libspatialite-dev \
    libhdf4-alt-dev \
    libhdf5-serial-dev \
    bash-completion \
    cmake

# Prepare OCI driver for GDAL
RUN cd src && unzip '*.zip' \
    && mkdir -p /home/niper/software/oracle \
    && cp -R instantclient_12_2 /home/niper/software/oracle \
    && cd /home/niper/software/oracle/instantclient_12_2 \
    && ln -s libclntsh.so.12.1 libclntsh.so \
    && ln -s libocci.so.12.1 libocci.so \
    && mkdir lib \
    && for i in $(ls "$ORACLE_HOME"/*.so); do ln -s $i "$ORACLE_HOME"/lib; done
    

# Compile and install OpenJPEG
RUN cd src && tar -xvf openjpeg-${OPENJPEG_VERSION}.tar.gz && cd openjpeg-${OPENJPEG_VERSION}/ \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROOTDIR \
    && make -j 12 && make install && make clean \
    && cd $ROOTDIR && rm -Rf src/openjpeg*

# Compile and install GDAL
RUN cd src && tar -xvf gdal-${GDAL_VERSION}.tar.gz && cd gdal-${GDAL_VERSION} \
    && ./configure --with-python --with-spatialite --with-pg --with-curl --with-openjpeg --with-oci=yes --with-oci-include=/home/niper/software/oracle/instantclient_12_2/sdk/include --with-oci-lib=/home/niper/software/oracle/instantclient_12_2 \
    && make -j 12 && make install && make clean && ldconfig \
    && apt-get update -y \
    && apt-get remove -y --purge build-essential \
    && cd $ROOTDIR && cd src/gdal-${GDAL_VERSION}/swig/python \
    && python3 setup.py build \
    && python3 setup.py install \
    && cd $ROOTDIR && rm -Rf src/gdal*

# Command keeping container running for further execution 
CMD tail -f /etc/passwd 

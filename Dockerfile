# Ubuntu 18.04 Bionic Beaver
FROM ubuntu:bionic

MAINTAINER Nikolaj Persson <niper@sdfe.dk>

ENV ORACLE_HOME=/home/kfadm/software/oracle/instantclient_12_2
ENV PATH=$PATH:$ORACLE_HOME
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME
ENV ROOTDIR /usr/local/
ENV GDAL_VERSION 2.4.0
ENV OPENJPEG_VERSION 2.3.0
ENV PGCLIENTENCODING=LATIN1

WORKDIR $ROOTDIR/

# geos API
COPY geos-3.7.0.tar.bz2 $ROOTDIR/src/

# zip files for instant client
COPY instantclient-basic-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/
COPY instantclient-sqlplus-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/
COPY instantclient-sdk-linux.x64-12.2.0.1.0.zip  $ROOTDIR/src/

# gdal 
ADD http://download.osgeo.org/gdal/${GDAL_VERSION}/gdal-${GDAL_VERSION}.tar.gz $ROOTDIR/src/

# openjpeg
COPY ${OPENJPEG_VERSION}.tar.gz $ROOTDIR/src/openjpeg-${OPENJPEG_VERSION}.tar.gz

# libecwj2-3.3
COPY libecwj2-3.3-2006-09-06.zip $ROOTDIR/src/

# dependencies
RUN apt-get update -y && apt-get install -y \
    libaio1 \
    bzip2 \ 
    unzip \
    software-properties-common \
    build-essential \
    python-dev \
    git \
    python3-dev \
    python-numpy \
    python3-numpy \
    python-pip \
    python3-pip \ 
    cython \
    python-pytest \ 
    python-nose \ 
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

#Compile with geos
RUN cd src && bunzip2 -f geos-3.7.0.tar.bz2 \
    && tar xvf geos-3.7.0.tar \
    && cd geos-3.7.0 \
    && ./configure \
    && make -j 12 \
    && make install 

# Prepare OCI driver for GDAL
RUN cd src && unzip '*.zip' \
    && mkdir -p /home/kfadm/software/oracle \
    && cp -R instantclient_12_2 /home/kfadm/software/oracle \
    && cd /home/kfadm/software/oracle/instantclient_12_2 \
    && ln -s libclntsh.so.12.1 libclntsh.so \
    && ln -s libocci.so.12.1 libocci.so \
    && mkdir lib \
    && for i in $(ls "$ORACLE_HOME"/*.so); do ln -s $i "$ORACLE_HOME"/lib; done
   
# compile and install ECW
RUN cd src && unzip -o libecwj2-3.3-2006-09-06.zip \
    && cd libecwj2-3.3 \
    && ./configure --prefix=/usr/local \
    && make -j 12 && make install && make clean \
    && cd $ROOTDIR && rm -Rf src/libecw*

## Compile and install OpenJPEG
RUN cd src && tar -xvf openjpeg-${OPENJPEG_VERSION}.tar.gz && cd openjpeg-${OPENJPEG_VERSION}/ \
    && mkdir build && cd build \
    && cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$ROOTDIR \
    && make -j 12 && make install && make clean \
    && cd $ROOTDIR && rm -Rf src/openjpeg*

# Compile and install GDAL including GDAL-python-bindings 
RUN cd src && tar -xvf gdal-${GDAL_VERSION}.tar.gz && cd gdal-${GDAL_VERSION} \
    && ./configure \ 
        --with-python \
        --with-geos=yes \ 
        --with-spatialite \ 
        --with-ecw=/usr/local \
        --with-pg \
        --with-curl \ 
        --with-openjpeg \
        --with-oci=yes \
        --with-oci-include=/home/kfadm/software/oracle/instantclient_12_2/sdk/include \
        --with-oci-lib=/home/kfadm/software/oracle/instantclient_12_2 \
    && make -j 12 && make install && make clean && ldconfig \
    && apt-get update -y \
    && apt-get remove -y --purge build-essential \
    && cd $ROOTDIR && cd src/gdal-${GDAL_VERSION}/swig/python \
    && python3 setup.py build \
    && python3 setup.py install \
    && cd $ROOTDIR && rm -Rf src/gdal*
    
#install python module add-on for ogr2ogr [fiona]
#uses gdal_path from above
RUN cd $ROOTDIR \
    && git clone https://git@github.com/Toblerity/Fiona.git \
    && cd Fiona && pip install -e . \
    && cd $ROOTDIR

#Command keeping container running for further execution 
CMD tail -f /etc/passwd 

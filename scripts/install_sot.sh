#! /bin/bash
# Please set these values before running the script!
# We recommend something like:
#   SRC_DIR=$HOME/devel/ros/src
#   INSTALL_DIR=$HOME/devel/ros/install
# clean the environment
set -e

echo $PATH

install_level=$2

if [ $install_level -lt -1 ]; then
 exit 0
fi 

. /opt/ros/electric/setup.bash

LAAS_USER_ACCOUNT=ostasse

ROS_DEVEL_NAME=$1
SRC_DIR=$HOME/devel/$ROS_DEVEL_NAME/src
INSTALL_DIR=$HOME/devel/$ROS_DEVEL_NAME/install

export ROS_ROOT=/opt/ros/electric/ros
export PATH=$ROS_ROOT/bin:$PATH
export PYTHONPATH=$ROS_ROOT/core/roslib/src:$PYTHONPATH
export ROS_PACKAGE_PATH=~/devel/$ROS_DEVEL_NAME:~/devel/$ROS_DEVEL_NAME/stacks/hrp2:~/devel/$ROS_DEVEL_NAME/stacks/ethzasl_ptam:/opt/ros/electric/stacks:/opt/ros/electric/stacks/ros_realtime:$ROS_PACKAGE_PATH


# Use environment variables to override these options
: ${GIT=/usr/bin/git}
: ${CMAKE=/usr/bin/cmake}
: ${MAKE=/usr/bin/make}

: ${GIT_CLONE_OPTS=}
: ${MAKE_OPTS=-k}

: ${BUILD_TYPE=RELEASE}
: ${ROBOT=HRP2LAAS}

# Compilation flags
: ${CFLAGS="-O3 -pipe -fomit-frame-pointer -ggdb3 -DNDEBUG"}
: ${CXX_FLAGS=${CFLAGS}}
: ${LDFLAGS="-Xlinker -export-dynamic -Wl,-O1 -Wl,-Bsymbolic-functions"}

# Git URLs
JRL_URI=git@github.com:jrl-umi3218
LAAS_URI=git@github.com:laas

# If you do not have a GitHub account (read-only):
#JRL_URI=git://github.com:jrl-umi3218
#LAAS_URI=git://github.com:laas

# HTTP protocol can also be used:
#JRL_URI=https://thomas-moulard@github.com/jrl-umi3218
#LAAS_URI=https://thomas-moulard@github.com/laas

LAAS_PRIVATE_URI=ssh://${LAAS_USER_ACCOUNT}@softs.laas.fr/git/jrl
################
# Installation #
################
set -e
if test x"$SRC_DIR" = x; then
    echo "Please set the source dir"
    exit 1
fi
if test x"$INSTALL_DIR" = x; then
    echo "Please set the install dir"
    exit 1
fi

mkdir -p                \
    $INSTALL_DIR	\
    $SRC_DIR/oss        \
    $SRC_DIR/laas       \
    $SRC_DIR/jrl        \
    $SRC_DIR/planning   \
    $SRC_DIR/robots     \
    $SRC_DIR/sot

install_git()
{
    cd /tmp
    rm -f git-1.7.4.1.tar.bz2
    wget http://kernel.org/pub/software/scm/git/git-1.7.4.1.tar.bz2
    mv git-1.7.4.1.tar.bz2 $SRC_DIR/oss/
    cd $SRC_DIR/oss
    tar xjvf git-1.7.4.1.tar.bz2
    cd git-1.7.4.1
    ./configure --prefix=${INSTALL_DIR}
    ${MAKE} ${MAKE_OPTS}
    ${MAKE} ${MAKE_OPTS} install
}

install_doxygen()
{
    cd /tmp
    rm -f doxygen-1.7.3.src.tar.gz
    wget http://ftp.stack.nl/pub/users/dimitri/doxygen-1.7.3.src.tar.gz
    mv doxygen-1.7.3.src.tar.gz $SRC_DIR/oss/
    cd $SRC_DIR/oss
    tar xzvf doxygen-1.7.3.src.tar.gz
    cd doxygen-1.7.3
    ./configure --prefix ${INSTALL_DIR}
    ${MAKE} ${MAKE_OPTS}
    ${MAKE} ${MAKE_OPTS} install
}

install_pkg()
{

    cd $1
    if test -d "$2"; then
	cd $2
    	${GIT} pull
    else
    	${GIT} ${GIT_CLONE_OPTS} clone $3/$2
        cd $2
    fi
    if ! test x"$4" = x; then
       if ${GIT} branch | grep $4 ; then
	   ${GIT} checkout $4
       else
	   ${GIT} checkout -b $4 origin/$4
       fi
    fi
    if ! test x"$5" = x; then
	local_build_type=$5
	local_cflags=""
    else
	local_build_type=${BUILD_TYPE}
	local_cflags=${CFLAGS}
    fi


    ${GIT} submodule init && ${GIT} submodule update
    mkdir -p _build-$local_build_type
    cd _build-$local_build_type
    echo ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type=\"${LDFLAGS}\" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DSMALLMATRIX=jrl-mathtools -DROBOT=${ROBOT} \
    	-DCMAKE_CXX_FLAGS=\"$local_cflags\" ..
    ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type="${LDFLAGS}" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DSMALLMATRIX=jrl-mathtools -DROBOT=${ROBOT} \
	-DCMAKE_CXX_FLAGS="$local_cflags" ..
    ${MAKE} ${MAKE_OPTS}
    ${MAKE} install ${MAKE_OPTS}
}

install_python_pkg()
{
    cd "$1"
    if test -d "$2"; then
	cd "$2"
	${GIT} pull
    else
	${GIT} ${GIT_CLONE_OPTS} clone "$3/$2"
	cd "$2"
    fi
    if ! test x"$4" = x; then
       if ${GIT} branch | grep "$4" ; then
	   ${GIT} checkout "$4"
       else
	   ${GIT} checkout -b "$4" "origin/$4"
       fi
    fi
    ${GIT} submodule init && ${GIT} submodule update
    python setup.py install --prefix=${INSTALL_DIR}
}

install_ros_ws()
{
    # sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu lucid main" > /etc/apt/sources.list.d/ros-latest.list'
    # sudo chmod 644 /etc/apt/sources.list.d/ros-latest.list
    # wget http://packages.ros.org/ros.key -O - | sudo apt-key add -
    # sudo apt-get install ros-electric-desktop-full
    # sudo apt-get install python-setuptools python-pip
    # sudo pip install -U rosinstall
    rosinstall ~/devel/$ROS_DEVEL_NAME https://raw.github.com/laas/ros/master/laas.rosinstall /opt/ros/electric
    rosinstall ~/devel/$ROS_DEVEL_NAME https://raw.github.com/laas/ros/master/laas-private.rosinstall
    source ~/devel/$ROS_DEVEL_NAME/setup.bash
    # To be done when dynamic_graph is installed.
    roscd dynamic_graph_bridge 
    rosmake
    roscd hrp2_14_description
    rosmake
    # Warning        
    roscd openhrp_bridge
    # Break here
    # Go to the build of openhrp_bridge
    # Set the robot variable then
    # build the repository again.
    rosmake

}

# Setup environment variables.
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib"
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig"
export PYTHONPATH="${INSTALL_DIR}/lib/python2.6/dist-packages:$PYTHONPATH:$PYTHON_PATH"
export PATH="$PATH:${INSTALL_DIR}/bin:${INSTALL_DIR}/sbin"

# --- Third party tools
if [ $install_level -lt -2 ]; then
  install_git
fi
if [ $install_level -lt -1 ]; then
  install_doxygen
fi

if [ $install_level -lt 1 ]; then
  install_ros_ws
fi

# --- Mathematical tools
if [ $install_level -lt 2 ]; then
  install_pkg $SRC_DIR/jrl jrl-mathtools ${JRL_URI}
fi

if [ $install_level -lt 3 ]; then
  install_pkg $SRC_DIR/jrl jrl-mal ${JRL_URI} topic/python
fi

# --- Interfaces
if [ $install_level -lt 4 ]; then
  install_pkg $SRC_DIR/laas abstract-robot-dynamics ${LAAS_URI}
fi 

# --- Dynamics implementation
if [ $install_level -lt 5 ]; then
  install_pkg $SRC_DIR/jrl jrl-dynamics ${JRL_URI}
fi

# --- walkgen implementation
if [ $install_level -lt 6 ]; then
  install_pkg $SRC_DIR/jrl jrl-walkgen ${JRL_URI}
fi

# --- Robots private data
# Install by hand the following packages to have hrp-2 support:
# - hrp2_10
# - hrp2_14
# - hrp2Dynamics
# - hrp2-10-optimized
#

if [ $install_level -lt 7 ]; then 
  install_pkg $SRC_DIR/robots hrp2_14 ${LAAS_PRIVATE_URI}
fi

if [ $install_level -lt 8 ]; then 
  install_pkg $SRC_DIR/robots hrp2Dynamics ${LAAS_PRIVATE_URI}
fi

if [ $install_level -lt 9 ]; then 
  install_pkg $SRC_DIR/robots hrp2_10 ${LAAS_PRIVATE_URI}
fi

if [ $install_level -lt 10 ]; then 
  install_pkg $SRC_DIR/robots hrp2-10-optimized ${LAAS_PRIVATE_URI}/robots
fi

# --- Sot 
if [ $install_level -lt 11 ]; then 
  install_pkg $SRC_DIR/sot dynamic-graph ${JRL_URI}
fi

if [ $install_level -lt 12 ]; then 
  install_pkg $SRC_DIR/sot dynamic-graph-python ${JRL_URI}
fi

if [ $install_level -lt 13 ]; then 
  install_pkg $SRC_DIR/laas hpp-util ${LAAS_URI}
fi

if [ $install_level -lt 14 ]; then 
  install_pkg $SRC_DIR/laas hpp-template-corba ${LAAS_URI}
fi

if [ $install_level -lt 15 ]; then 
  install_pkg $SRC_DIR/sot dynamic-graph-corba ${LAAS_URI}
fi

if [ $install_level -lt 16 ]; then 
  install_pkg $SRC_DIR/sot sot-core ${JRL_URI}
fi

if [ $install_level -lt 17 ]; then 
  install_pkg $SRC_DIR/sot sot-dynamic ${JRL_URI}
fi

if [ $install_level -lt 18 ]; then 
  install_pkg $SRC_DIR/sot sot-hrp2 ${LAAS_URI}
fi

if [ $install_level -lt 19 ]; then 
  install_pkg $SRC_DIR/sot sot-hrp2-hrpsys ${LAAS_URI}
fi

if [ $install_level -lt 20 ]; then 
  install_pkg $SRC_DIR/sot sot-pattern-generator ${JRL_URI} topic/python
fi


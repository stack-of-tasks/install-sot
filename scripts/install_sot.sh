#! /bin/bash
# Olivier Stasse, LAAS/CNRS, Copyright 2013
# Thomas Moulard, LAAS/CNRS, Copyright 2011, 2012, 2013
# 
# Please set these values before running the script!
# We recommend something like:
#   SRC_DIR=$HOME/devel/ros/src
#   INSTALL_DIR=$HOME/devel/ros/install
# clean the environment

usage_message()
{
  echo "Usage: `basename $0` [-h] ros_subdir installation_level"
  echo ""
  echo "  ros_subdir: The sub directory where to install the ros workspace."
  echo "    The script creates a variable ros_install_path from ros_subdir:"
  echo "    ros_install_path=$HOME/devel/$ros_subdir"
  echo "    The git repositories are cloned in ros_install_path/src and"
  echo "    installed in ros_install_path/install."
  echo "" 
  echo "  installation_level: Specifies at which step the script should start"
  echo "    the installation."
  echo ""
  echo "Options:"
  echo "   -h : Display help"
  echo "   -l : Display the steps where the script can be started for installing."
  echo "        This also display the internal instructions run by the script."
  echo "        To use -l you HAVE TO specify ros_install_path and installation_level." 
  echo "        With -l the instructions are displayed but not run."
  echo "   -g : OpenHRP 3.0.7 has a priority than OpenHRP 3.1.0. Default is the reverse. "
  echo ""
  if [ "${LAAS_USER_ACCOUNT}" == "" ]; then
    echo "If you have a laas user account you should set the environment variable"
    echo "LAAS_USER_ACCOUNT to have read-write rights on the repositories"
    echo "otherwise they will be uploaded with read-only rights."
  fi
}

## Detect if General Robotix software is present
detect_grx()
{
    GRX_FOUND=""
    priorityvar1=$1
    if (( priorityvar1 > 0 )); then
      if [ -d /opt/grx3.0 ]; then
        GRX_FOUND="openhrp-3.0.7"
      fi  
      # OpenHRP 3.1.0 takes over OpenHRP 3.0.7
      if [ -d /opt/grx ]; then
        GRX_FOUND="openhrp-3.1.0"
      fi
    else
      if [ -d /opt/grx ]; then
        GRX_FOUND="openhrp-3.1.0"
      fi
      # OpenHRP 3.0.7 takes over OpenHRP 3.1.0
      if [ -d /opt/grx3.0 ]; then
        GRX_FOUND="openhrp-3.0.7"
      fi  
    fi

    echo "GRX_FOUND is ${GRX_FOUND}"
}


UPDATE_PACKAGE=1		# 1 to run the update the packages, 0 otherwise
COMPILE_PACKAGE=1       # 0 to compile the packages, 0 otherwise

set -e
ARG_DETECT_GRX=1
DISPLAY_LIST_INSTRUCTIONS=0

# Deal with options
while getopts ":ghl:" option; do
  case "$option" in
    g)  ARG_DETECT_GRX=0
        ;;
    h)  # it's always useful to provide some help 
        usage_message
        exit 0 
        ;;
    l)  DISPLAY_LIST_INSTRUCTIONS=1
        ;;      
    :)  echo "Error: -$option requires an argument" 
        usage_message
        exit 1
        ;;
    ?)  echo "Error: unknown option -$option" 
        usage_message
        exit 1
        ;;
  esac
done    
shift $(($OPTIND-1))

ROS_VERSION=electric # ROS VERSION used: electric or fuerte
 
## Environment variables

# Setup ROS variables
. /opt/ros/$ROS_VERSION/setup.bash

ROS_DEVEL_NAME=$1
SRC_DIR=$HOME/devel/$ROS_DEVEL_NAME/src
INSTALL_DIR=$HOME/devel/$ROS_DEVEL_NAME/install

export ROS_ROOT=/opt/ros/$ROS_VERSION/ros
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

if [ "${LAAS_USER_ACCOUNT}" == "" ]; then
  # If you do not have a GitHub account (read-only):
  INRIA_URI=https://gforge.inria.fr/git/romeo-sot
  JRL_URI=git://github.com/jrl-umi3218
  LAAS_URI=git://github.com/laas 
  STACK_OF_TASKS_URI=git://github.com/stack-of-tasks
else 
  # Git URLs
  INRIA_URI=https://gforge.inria.fr/git/romeo-sot
  JRL_URI=git@github.com:jrl-umi3218
  LAAS_URI=git@github.com:laas
  LAAS_PRIVATE_URI=ssh://${LAAS_USER_ACCOUNT}@softs.laas.fr/git/jrl
  STACK_OF_TASKS_URI=git://github.com/stack-of-tasks
fi



# HTTP protocol can also be used:
#JRL_URI=https://${LAAS_USER_ACCOUNT}@github.com/jrl-umi3218
#LAAS_URI=https://${LAAS_USER_ACCOUNT}@github.com/laas


create_local_db()
{
  local_db_file="/tmp/install_sod_db.dat"
  if [ -f $local_db_file ] ; then
      rm $local_db_file
  fi

  index=0;
  
  inst_array[index]="install_git"
  let "index= $index +1"

  inst_array[index]="install_doxygen"
  let "index= $index +1"

  inst_array[index]="install_ros_legacy"
  let "index= $index +1"
  
  inst_array[index]="install_ros_ws"
  let "index= $index +1"

  inst_array[index]="install_pkg $SRC_DIR/robots romeo-sot.git ${INRIA_URI}"
  let "index= $index + 1"

  if [ "${LAAS_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_ros_ws_package hrp2_14_description"
    let "index= $index + 1"
  fi

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-mathtools ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-mal ${JRL_URI} topic/python"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas abstract-robot-dynamics ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-dynamics ${JRL_URI}"
  let "index= $index + 1"

  if [ "${LAAS_PRIVATE_URI}" != "" ]; then 
    inst_array[index]="install_pkg $SRC_DIR/robots hrp2_14 ${LAAS_PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2Dynamics ${LAAS_PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2_10 ${LAAS_PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2-10-optimized ${LAAS_PRIVATE_URI}/robots"
    let "index= $index + 1"
  fi

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-walkgen ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph-python ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas hpp-util ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas hpp-template-corba ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-core ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph-corba ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-tools ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-dynamic ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-pattern-generator ${JRL_URI} topic/python"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package jrl_dynamics_urdf"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package dynamic_graph_bridge"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package romeo_description"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/robots sot-romeo.git ${JRL_URI}"
  let "index= $index + 1"

  if [ "${LAAS_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp2 ${LAAS_URI}"
    let "index= $index + 1"

    if [ "$GRX_FOUND" == "openhrp-3.0.7" ]; then
      
      inst_array[index]="install_ros_ws_package openhrp_bridge"
      let "index= $index + 1"

      inst_array[index]="install_ros_ws_package openhrp_bridge_msgs"
      let "index= $index + 1"

      inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp2-hrpsys ${LAAS_URI}"
      let "index= $index + 1"
    fi

    if [ "$GRX_FOUND" == "openhrp-3.1.0" ]; then
      inst_array[index]="install_pkg $SRC_DIR/sot sot-hrprtc-hrp2 ${STACK_OF_TASKS_URI}"
      let "index= $index + 1"
    fi
    
  fi

  for ((lindex=0; lindex<${#inst_array[@]} ; lindex++ ))
  do 
      echo ${inst_array[$lindex]} >> $local_db_file
  done

}

display_list_instructions()
{
  for ((lindex=0; lindex<${#inst_array[@]} ; lindex++ ))
  do 
      echo "$lindex - ${inst_array[$lindex]}"
  done
}

detect_grx $ARG_DETECT_GRX
create_local_db

if (( DISPLAY_LIST_INSTRUCTIONS > 0 )); then
  display_list_instructions
  exit 0
fi

# Check number of arguments
EXPECTED_ARGS=2
if [ $# -ne $EXPECTED_ARGS ]
then
  echo "Error: Bad number of parameters " $#
  usage_message
  exit $E_BADARGS
else
  echo "Parameters found:" $1 $2
fi

install_level=$2

if [ $install_level -lt -1 ]; then
 exit 0
fi


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
    #checking whether git is already installed.
    git --version &> /dev/null
    if [ $? -eq 0 ];  then
      res=`git --version | awk ' { print $3 }'`
      if [[ "$res" > "1.7.4.1" ]] || [[ "$res" == "1.7.4.1" ]]; then
        # 'Git already installed'
        return
      else
        echo 'Git installed but with a deprecated version. Updating.'
      fi
    fi

    #install git 1.7.4.1
    cd /tmp
    rm -f git-1.7.4.1.tar.bz2
    wget http://pkgs.fedoraproject.org/repo/pkgs/git/git-1.7.4.1.tar.bz2/76898de4566d11c0d0eec7e99edc2b5c/git-1.7.4.1.tar.bz2
    mkdir -p $SRC_DIR/oss/
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
    #checking whether doxygen is already installed.
    doxygen --version &> /dev/null
    if [ $? -eq 0 ];  then
      res=`doxygen --version | awk ' { print $1 }'`
      if [[ "$res" > "1.7.3" ]] || [[ "$res" == "1.7.3" ]]; then
        # 'doxygen already installed'
        return
      else
        echo 'doxygen installed but with a deprecated version. Updating.'
      fi
    fi

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

update_pkg()
{
    OLD_PWD=`pwd`

    # Update the repo
    if test -d "$2"; then
	cd $2
    	${GIT} pull
    # Or make the first clone
    else
        ${GIT} ${GIT_CLONE_OPTS} clone $3/$2 $2
        cd $2
    fi

    # Switch to the branch if needed
    if ! test x"$4" = x; then
       if ${GIT} branch | grep $4 ; then
	   ${GIT} checkout $4
       else
	   ${GIT} checkout -b $4 origin/$4
       fi
    fi

    # Configure the repository
    ${GIT} submodule init && ${GIT} submodule update

    cd $OLD_PWD
}

compile_pkg()
{
    # Update the repo
    if ! test -d "$2"; then
        echo The repository $2 does not exist
        exit -1
    fi

    cd $2

    # Choose the build type
    if ! test x"$5" = x; then
	local_build_type=$5
	local_cflags=""
    else
	local_build_type=${BUILD_TYPE}
	local_cflags=${CFLAGS}
    fi

    mkdir -p _build-$local_build_type
    cd _build-$local_build_type
    echo ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type=\"${LDFLAGS}\" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DSMALLMATRIX=jrl-mathtools -DROBOT=${ROBOT} \
	-DCXX_DISABLE_WERROR=1 \
    	-DCMAKE_CXX_FLAGS=\"$local_cflags\" ..
    ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type="${LDFLAGS}" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DSMALLMATRIX=jrl-mathtools -DROBOT=${ROBOT} \
	-DCXX_DISABLE_WERROR=1 \
	-DCMAKE_CXX_FLAGS="$local_cflags" ..

    # Build the repository
    ${MAKE} ${MAKE_OPTS}
    ${MAKE} install ${MAKE_OPTS}
}

install_pkg()
{
    # Go to the repository
    cd $1

	if (( UPDATE_PACKAGE > 0 )); then
	    update_pkg $@
	fi
	if (( COMPILE_PACKAGE > 0 )); then
	    compile_pkg $@
	fi
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

install_ros_legacy()
{
    sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu lucid main" > /etc/apt/sources.list.d/ros-latest.list'
    sudo chmod 644 /etc/apt/sources.list.d/ros-latest.list
    wget http://packages.ros.org/ros.key -O - | sudo apt-key add -
    sudo apt-get install ros-$ROS_VERSION-desktop-full
    sudo apt-get install python-setuptools python-pip
    sudo pip install -U rosinstall
}

install_ros_ws()
{
    rosinstall ~/devel/$ROS_DEVEL_NAME https://raw.github.com/laas/ros/master/laas.rosinstall /opt/ros/$ROS_VERSION
    if [ "${LAAS_PRIVATE_URI}" != "" ]; then
      rosinstall ~/devel/$ROS_DEVEL_NAME https://raw.github.com/laas/ros/master/laas-private.rosinstall
    fi
}

install_ros_ws_package()
{
	if (( COMPILE_PACKAGE = 0 )); then
	    return
	fi

    echo "### Install ros package $1"
    # Go to the rospackage build directory.
    roscd $1
    echo "PWD:"$PWD
    if [ ! -d build ]; then
      mkdir -p build
    fi
    cd build

    # Choose the build type
    if ! test x"$2" = x; then
	local_build_type=$2
	local_cflags=""
    else
	local_build_type=${BUILD_TYPE}
	local_cflags=${CFLAGS}
    fi

    # Configure the package
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

	if [ "$1" == "dynamic_graph_bridge" ]; then
  	  ${MAKE} install
	fi

}    

update_ros_setup()
{
  echo "update ros setup"
  if [ -f ~/devel/$ROS_DEVEL_NAME/setup.bash ]; then 
    source ~/devel/$ROS_DEVEL_NAME/setup.bash
  fi
}


# Setup environment variables.
export LD_LIBRARY_PATH="${INSTALL_DIR}/lib"
arch_path=`dpkg-architecture -qDEB_HOST_MULTIARCH`
if [ $? -eq 0 ];  then
  export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/$arch_path/pkgconfig"
fi;
export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig":$PKG_CONFIG_PATH
export PYTHONPATH="${INSTALL_DIR}/lib/python2.6/dist-packages:$PYTHONPATH:$PYTHON_PATH"
export PATH="$PATH:${INSTALL_DIR}/bin:${INSTALL_DIR}/sbin"


run_instructions()
{
  echo "run instructions from $install_level to ${#inst_array[@]}"
  for ((lindex=$install_level; lindex<${#inst_array[@]} ; lindex++ ))
  do 
      echo
      if [ $lindex -ge 0 ]; then
        update_ros_setup
      fi

      echo "Eval ("$lindex"):" ${inst_array[$lindex]}
      ${inst_array[$lindex]}
  done
}

run_instructions
exit 0


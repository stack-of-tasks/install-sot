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
  echo "   -h : Display help."
  echo "   -r ros_release : Specifies the ros release to use."
  echo "   -l : Display the steps where the script can be started for installing."
  echo "        This also display the internal instructions run by the script."
  echo "        To use -l you HAVE TO specify ros_install_path and installation_level." 
  echo "        With -l the instructions are displayed but not run."
  echo "   -g : OpenHRP 3.0.7 has a priority than OpenHRP 3.1.0. Default is the reverse. "
  echo "   -m : Compile the sources without updating them "
  echo "   -u : Update the sources without compiling them "
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

REMOVE_CMAKECACHE=0     # 1 to rm CMakeCache.txt
UPDATE_PACKAGE=1        # 1 to run the update the packages, 0 otherwise
COMPILE_PACKAGE=1       # 1 to compile the packages, 0 otherwise

. /etc/lsb-release 
echo "Distribution is $DISTRIB_CODENAME"

set -e
ARG_DETECT_GRX=1
DISPLAY_LIST_INSTRUCTIONS=0

# Deal with options
while getopts ":cghlmur:" option; do
  case "$option" in
    g)  ARG_DETECT_GRX=0
        ;;
    h)  # it's always useful to provide some help 
        usage_message
        exit 0 
        ;;
    l)  DISPLAY_LIST_INSTRUCTIONS=1
        ;;

    c)  REMOVE_CMAKECACHE=1
		;;

    m)  COMPILE_PACKAGE=1
        UPDATE_PACKAGE=0
        ;;
    u)  COMPILE_PACKAGE=0
        UPDATE_PACKAGE=1
        ;;
    r)  ROS_VERSION=$OPTARG
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

if [ "$ROS_VERSION" == "" ]; then
  ROS_VERSION=electric # ROS VERSION by default electric
fi
echo "ROS_VERSION is $ROS_VERSION"
 
## Environment variables

# Setup ROS variables
if [ ! -d /opt/ros/$ROS_VERSION ]; then 
    echo "ROS_VERSION $ROS_VERSION does not appear to be installed"
    exit 1
fi

. /opt/ros/$ROS_VERSION/setup.bash

ROS_DEVEL_NAME=$1
SOT_ROOT_DIR=$HOME/devel/$ROS_DEVEL_NAME
SRC_DIR=$SOT_ROOT_DIR/src
INSTALL_DIR=$SOT_ROOT_DIR/install

export ROS_ROOT=/opt/ros/$ROS_VERSION/ros
export PATH=$ROS_ROOT/bin:$PATH
export PYTHONPATH=$ROS_ROOT/core/roslib/src:$PYTHONPATH
export ROS_PACKAGE_PATH=$SOT_ROOT_DIR:$SOT_ROOT_DIR/stacks/hrp2:/opt/ros/electric/stacks:/opt/ros/electric/stacks/ros_realtime:$ROS_PACKAGE_PATH

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

# Uncomment only if you have an account on this server.
IDH_PRIVATE_URI= #idh.lirmm.fr



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

  if [ "${IDH_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/robots hrp4_sot ${IDH_PRIVATE_URI}"
    let "index= $index + 1"
  fi

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

  inst_array[index]="install_pkg $SRC_DIR/sot soth ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-dyninv ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-application ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-pattern-generator ${JRL_URI} topic/python"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package jrl_dynamics_urdf"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package dynamic_graph_bridge"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package romeo_description"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-romeo.git ${JRL_URI}"
  let "index= $index + 1"

  if [ "${IDH_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_ros_ws_package hrp4_description"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp4 ${IDH_PRIVATE_URI}"
    let "index= $index + 1"
  fi

  if [ "${LAAS_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp2 ${LAAS_URI}"
    let "index= $index + 1"
  fi

  if [ "${LAAS_PRIVATE_URI}" != "" ] || [ "${IDH_PRIVATE_URI}" != "" ]; then
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

# compare two versions. Taks two arguments: a and b
# return -1 if a<b, 0 if a=b, 1 if a>b
# source: http://stackoverflow.com/questions/3511006/how-to-compare-versions-of-some-products-in-unix-shell
compare_versions ()
{
  typeset    IFS='.'
  typeset -a v1=( $1 )
  typeset -a v2=( $2 )
  typeset    n diff

  for (( n=0; n<4; n+=1 )); do
    diff=$((v1[n]-v2[n]))
    if [ $diff -ne 0 ] ; then
      [ $diff -le 0 ] && echo '-1' || echo '1'
      return
    fi
  done
  echo '0'
}

install_git()
{
    #checking whether git is already installed.
    git --version &> /dev/null
    if [ $? -eq 0 ];  then
      res=`git --version | awk ' { print $3 }'`
      comp=`compare_versions "$res" "1.7.4.1"`
      if [[ $comp -ge 0 ]]; then
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
      comp=`compare_versions "$res" "1.7.3"`
      if [[ $comp -ge 0 ]]; then
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
    if [ $REMOVE_CMAKECACHE -eq 1 ]; then
        rm -f CMakeCache.txt
    fi
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
    sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu '$DISTRIB_CODENAME' main" > /etc/apt/sources.list.d/ros-latest.list'
    sudo chmod 644 /etc/apt/sources.list.d/ros-latest.list
    wget http://packages.ros.org/ros.key -O - | sudo apt-key add -
    sudo apt-get install ros-$ROS_VERSION-desktop-full
    sudo apt-get install ros-$ROS_VERSION-pr2-mechanism      # for realtime_tools
    sudo apt-get install ros-$ROS_VERSION-documentation
    sudo apt-get install python-setuptools python-pip
    sudo apt-get install python-rosinstall

    if [ "$ROS_VERSION" == "fuerte" ]; then
      sudo apt-get install ros-fuerte-robot-model
      sudo apt-get install ros-fuerte-pr2-mechanism
    fi
}




# create a config file to load all env parameters
install_config()
{
    # get python site packages path
    PYTHON_SITELIB=`python -c "import sys, os; print os.sep.join(['lib', 'python' + sys.version[:3], 'site-packages'])"`

    # get dpkg version
    dpkg_version=`dpkg-architecture --version | head -n 1 | awk '{print $4}'`
    comp=`compare_versions "$dpkg_version" "1.16.0"`
    if [[ $comp -ge 0 ]];  then
      arch_path=`dpkg-architecture -qDEB_HOST_MULTIARCH`
    fi;

    # load ros info
    source $SOT_ROOT_DIR/setup.bash

    # create the file
    CONFIG_FILE=config.sh
    echo "#!/bin/sh"                                >  $CONFIG_FILE
    echo "source /opt/ros/$ROS_DISTRO/setup.bash"   >> $CONFIG_FILE
    echo "ROS_WS_DIR=\$HOME/devel/$ROS_DEVEL_NAME"  >> $CONFIG_FILE
    echo "source \$ROS_WS_DIR/setup.bash"           >> $CONFIG_FILE
    echo "ROS_WS_DIR=\$HOME/devel/$ROS_DEVEL_NAME"  >> $CONFIG_FILE
    echo "ROS_INSTALL_DIR=$INSTALL_DIR"             >> $CONFIG_FILE
    echo "export ROBOT=\"$ROBOT\""                  >> $CONFIG_FILE
    echo "export ROS_ROOT=/opt/ros/$ROS_DISTRO"     >> $CONFIG_FILE
    echo "export PATH=\$ROS_ROOT/bin:\$PATH"        >> $CONFIG_FILE
    echo "export PYTHONPATH=\$ROS_ROOT/core/roslib/src:\$ROS_INSTALL_DIR/$PYTHON_SITELIB:\$PYTHONPATH" >> $CONFIG_FILE
    echo "export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig:/opt/grx/lib/pkgconfig"     >> $CONFIG_FILE
    echo "export ROS_PACKAGE_PATH=\$ROS_WS_DIR:\$ROS_WS_DIR/stacks/hrp2:\$ROS_WS_DIR/stacks/ethzasl_ptam:/opt/ros/${ROS_DISTRO}/stacks:/opt/ros/\${ROS_DISTRO}/stacks/ros_realtime:\$ROS_PACKAGE_PATH" >> $CONFIG_FILE
    echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib/plugin:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
    echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
    if [ $? -eq 0 ];  then
        echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib/$arch_path/plugin:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
        echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib/$arch_path:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
    fi;
    echo "export ROS_MASTER_URI=http://localhost:11311" >> $CONFIG_FILE
}


# install all ros stack required
install_ros_ws()
{
    # Current groovy and hydro are considered likewise.
    gh_ros_sub_dir=master
    if [ "$ROS_VERSION" == "electric" ]; then
        gh_ros_sub_dir=topic/electric
    fi
    if [ "$ROS_VERSION" == "fuerte" ]; then
        gh_ros_sub_dir=topic/fuerte
    fi

    rosinstall $SOT_ROOT_DIR https://raw.github.com/laas/ros/$gh_ros_sub_dir/laas.rosinstall /opt/ros/$ROS_VERSION
    if [ "${LAAS_PRIVATE_URI}" != "" ]; then
      rosinstall $SOT_ROOT_DIR https://raw.github.com/laas/ros/$gh_ros_sub_dir/laas-private.rosinstall
    fi

    if [ "${IDH_PRIVATE_URI}" != "" ]; then
      echo -e "- git:\n    uri: git@idh.lirmm.fr:mcp/ros/hrp4/hrp4_urdf.git\n" \
           "   local-name: stacks/hrp4\n    version: "${ROS_VERSION} > /tmp/idh-private.rosinstall
      rosinstall ~/devel/$ROS_DEVEL_NAME  /tmp/idh-private.rosinstall
    fi

    # create the config file.
    install_config
}

install_ros_ws_package()
{
    if [ $COMPILE_PACKAGE -eq 0 ]; then
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
    if [ $REMOVE_CMAKECACHE -eq 1 ]; then
        rm -f CMakeCache.txt
    fi

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

	if [ "$1" == "dynamic_graph_bridge" ] || [ "$1" == "openhrp_bridge" ]; then
  	  ${MAKE} install
	fi

}    

update_ros_setup()
{
  echo "update ros setup"
  if [ -f $SOT_ROOT_DIR/setup.bash ]; then 
    source $SOT_ROOT_DIR/setup.bash
  fi
}


# Setup environment variables.
if [ "$GRX_FOUND" == "openhrp-3.1.0" ]; then
  export PKG_CONFIG_PATH="/opt/grx/lib/pkgconfig/":$PKG_CONFIG_PATH
fi 

export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig":$PKG_CONFIG_PATH

# check the multiarch extension, only available for dpkg-architecture > 1.16.0
dpkg_version=`dpkg-architecture --version | head -n 1 | awk '{print $4}'`
comp=`compare_versions "$dpkg_version" "1.16.0"`
if [[ $comp -ge 0 ]];  then
  arch_path=`dpkg-architecture -qDEB_HOST_MULTIARCH`
  if [ $? -eq 0 ];  then
    export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/$arch_path/pkgconfig":$PKG_CONFIG_PATH
  fi;
fi;


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


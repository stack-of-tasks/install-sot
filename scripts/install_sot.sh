#! /bin/bash
# Olivier Stasse, Thomas Moulard, François Keith, Copyright 2011-2013
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
set -e

 # ------ #
 # README #
 # ------ #

# This script install the Stack of Tasks and all its dependencies from
# an empty environment.
#
# It is targeted toward the Ubuntu Linux distribution. In particular,
# the following releases are currently being tested:
#
# - Ubuntu 12.04 LTS Precise (32-bits and 64-bits)
#


# Override the locale.
LC_ALL='C'
export LC_ALL

me=$0
bme=`basename "$0"`

 # ----------------------- #
 # Customizable variables. #
 # ----------------------- #

: ${GIT=/usr/bin/git}
: ${CMAKE=/usr/bin/cmake}
: ${MAKE=/usr/bin/make}
: ${DOXYGEN=/usr/bin/doxygen}
: ${SUDO=sudo}

: ${GIT_OPTS=--quiet}
: ${GIT_CLONE_OPTS=--quiet --recursive}
: ${MAKE_OPTS=-k}

: ${BUILD_TYPE=RELEASE}

# Compilation flags
: ${CFLAGS="-O3 -pipe -fomit-frame-pointer -ggdb3 -DNDEBUG"}
: ${CXX_FLAGS=${CFLAGS}}
: ${LDFLAGS="-Xlinker -export-dynamic -Wl,-O1 -Wl,-Bsymbolic-functions"}

# Honour the apt_pref environment variable to allow the user to switch
# between apt-get and aptitude if desired.
: ${apt_pref=apt-get}

: ${QUIET=-qq} #FIXME: handle quiet level properly
APT_GET_INSTALL="$apt_pref -y $QUIET install"
APT_GET_UPDATE="$apt_pref -y  $QUIET update"


  # ---------------- #
  # Helper functions #
  # ---------------- #

set_colors()
{
  red='[0;31m';    lred='[1;31m'
  green='[0;32m';  lgreen='[1;32m'
  yellow='[0;33m'; lyellow='[1;33m'
  blue='[0;34m';   lblue='[1;34m'
  purple='[0;35m'; lpurple='[1;35m'
  cyan='[0;36m';   lcyan='[1;36m'
  grey='[0;37m';   lgrey='[1;37m'
  white='[0;38m';  lwhite='[1;38m'
  std='[m'
}

set_nocolors()
{
  red=;    lred=
  green=;  lgreen=
  yellow=; lyellow=
  blue=;   lblue=
  purple=; lpurple=
  cyan=;   lcyan=
  grey=;   lgrey=
  white=;  lwhite=
  std=
}

# abort err-msg
abort()
{
  echo "install_sot.sh: ${lred}abort${std}: $@" \
  | sed '1!s/^[ 	]*/             /' >&2
  exit 1
}

# warn msg
warn()
{
  echo "install_sot.sh: ${lred}warning${std}: $@" \
  | sed '1!s/^[ 	]*/             /' >&2
}

# notice msg
notice()
{
  echo "install_sot.sh: ${lyellow}notice${std}: $@" \
  | sed '1!s/^[ 	]*/              /' >&2
}

# yesno question
yesno()
{
  printf "$@ [y/N] "
  read answer || return 1
  case $answer in
    y* | Y*) return 0;;
    *)       return 1;;
  esac
  return 42 # should never happen...
}


  # -------------------- #
  # Actions definitions. #
  # -------------------- #

usage_message()
{
    echo "Usage: $me [-h] ros_subdir installation_level

  ros_subdir: The sub directory where to install the ros workspace.
    The script creates a variable ros_install_path from ros_subdir:
    ros_install_path=$HOME/devel/$ros_subdir
    The git repositories are cloned in ros_install_path/src and
    installed in ros_install_path/install.

  installation_level: Specifies at which step the script should start
    the installation.

Options:
   -h : Display help.
   -r ros_release : Specifies the ros release to use.
   -l : Display the steps where the script can be started for installing.
        This also display the internal instructions run by the script.
        To use -l you HAVE TO specify ros_install_path and installation_level.
        With -l the instructions are displayed but not run.
   -m : Compile the sources without updating them
   -o : print the git log of every package compiled and exit.
   -u : Update the sources without compiling them
   "

  if [ "${GITHUB_ACCOUNT}" == "" ]; then
    echo "* If you have a github user account you should set the environment variable"
    echo " GITHUB_ACCOUNT to have read-write rights on the repositories"
    echo " otherwise they will be uploaded with read-only rights."
  fi
  if [ "${PRIVATE_URI}" == "" ]; then
    echo "* If you have access to the private repositories for the HRP2."
    echo " Please uncomment the line defining PRIVATE_URI."
  fi
  if [ "${IDH_PRIVATE_URI}" == "" ]; then
    echo "* If you have access to the private repositories for the HRP4."
    echo " Please uncomment the line defining IDH_PRIVATE_URI."
  fi

  echo "
Report bugs to http://github.com/stack-of-tasks/install-sot/issues
For more information, see http://github.com/stack-of-tasks/install-sot
"
}


## Detect if General Robotix software is present
detect_grx()
{
    GRX_3_0_FOUND=""
    GRX_3_1_FOUND=""
    if [ -d /opt/grx ]; then
      GRX_3_1_FOUND="openhrp-3.1.0"
    fi
    # OpenHRP 3.0.7 takes over OpenHRP 3.1.0
    if [ -d /opt/grx3.0 ]; then
      GRX_3_0_FOUND="openhrp-3.0.7"
    fi

    if ! [ "${GRX_3_0_FOUND}" == "" ]; then
     notice "grx3.0 FOUND"
    fi
    if ! [ "${GRX_3_1_FOUND}" == "" ]; then
     notice "grx3.1 FOUND"
    fi
    if [ "${GRX_3_0_FOUND}" == "" ] && [ "${GRX_3_1_FOUND}" == "" ]; then
     warn "Neither grx3.0 nor grx3.1 could be found"
    fi
}

  # ------------------- #
  # `main' starts here. #
  # ------------------- #

# Define colors if stdout is a tty.
if test -t 1; then
  set_colors
else # stdout isn't a tty => don't print colors.
  set_nocolors
fi

# For dev's:
test "x$1" = x--debug && shift && set -x

REMOVE_CMAKECACHE=0     # 1 to rm CMakeCache.txt
UPDATE_PACKAGE=1        # 1 to run the update the packages, 0 otherwise
COMPILE_PACKAGE=1       # 1 to compile the packages, 0 otherwise
LOG_PACKAGE=0           # 1 to bypass the compilation, print the log and return

. /etc/lsb-release
notice "Distribution is $DISTRIB_CODENAME"

DISPLAY_LIST_INSTRUCTIONS=0

# Deal with options
while getopts ":chlmour:" option; do
  case "$option" in
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
    o)  COMPILE_PACKAGE=1
        LOG_PACKAGE=1
        UPDATE_PACKAGE=0
        ;;
    u)  COMPILE_PACKAGE=0
        UPDATE_PACKAGE=1
        ;;
    r)  ROS_VERSION=$OPTARG
        ;;
    :)  warn "Error: -$option requires an argument"
        usage_message
        exit 1
        ;;
    ?)  warn "Error: unknown option -$option"
        usage_message
        exit 1
        ;;
  esac
done
shift $(($OPTIND-1))


  # --------- #
  # variables #
  # --------- #


ROS_DEVEL_NAME=$1
SOT_ROOT_DIR=$HOME/devel/$ROS_DEVEL_NAME
SRC_DIR=$SOT_ROOT_DIR/src
INSTALL_DIR=$SOT_ROOT_DIR/install

# Uncomment only if you have an access to those
# PRIVATE_URI=git@github.com:jrl-umi3218

# Uncomment only if you have an account on this server.
# IDH_PRIVATE_URI=git@idh.lirmm.fr:sot

# Uncomment only if you have an account on this server.
# TRAC_LAAS_URI=trac.laas.fr

# Uncomment if you have a github account and writing access to the SoT repositories.
# GITHUB_ACCOUNT="yes"

if `test x${ROS_VERSION} == x`; then
    abort "ROS version unknown"
fi

if [ "${GITHUB_ACCOUNT}" == "" ]; then
    notice "GitHub account not set, cloning in read-only mode"
  # If you do not have a GitHub account (read-only):
    JRL_URI=git://github.com/jrl-umi3218
    LAAS_URI=git://github.com/laas
    STACK_OF_TASKS_URI=git://github.com/stack-of-tasks
else
    notice "GitHub account is set, cloning in read-write mode"
  # Git URLs
    JRL_URI=git@github.com:jrl-umi3218
    LAAS_URI=git@github.com:laas
    STACK_OF_TASKS_URI=git@github.com:stack-of-tasks
fi

INRIA_URI=https://gforge.inria.fr/git/romeo-sot

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

  inst_array[index]="install_apt_dependencies"
  let "index= $index +1"

  inst_array[index]="install_git"
  let "index= $index +1"

  inst_array[index]="install_doxygen"
  let "index= $index +1"

  inst_array[index]="install_ros_legacy"
  let "index= $index +1"

  inst_array[index]="install_ros_ws"
  let "index= $index +1"

  inst_array[index]="install_config"
  let "index= $index +1"

  inst_array[index]="install_pkg $SRC_DIR/robots romeo-sot.git ${INRIA_URI}"
  let "index= $index + 1"

  if [ "${IDH_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/robots hrp4_sot ${IDH_PRIVATE_URI}"
    let "index= $index + 1"
  fi

  if [ "${PRIVATE_URI}" != "" ]; then
      if [ "$ROS_VERSION" == "groovy" ]; then
	  inst_array[index]="install_ros_ws_package urdf_parser_py"
	  let "index= $index + 1"
	  inst_array[index]="install_ros_ws_package robot_capsule_urdf"
	  let "index= $index + 1"
	  inst_array[index]="install_ros_ws_package xml_reflection"
	  let "index= $index + 1"
      fi
      if [ "$ROS_VERSION" == "hydro" ]; then
	  inst_array[index]="install_ros_ws_package robot_capsule_urdf"
	  let "index= $index + 1"
      fi
    inst_array[index]="install_ros_ws_package hrp2_14_description"
    let "index= $index + 1"
  fi

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-mathtools ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-mal ${JRL_URI} master"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas abstract-robot-dynamics ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-dynamics ${JRL_URI}"
  let "index= $index + 1"

  if [ "${PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/robots hrp2-14 ${PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2-dynamics ${PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2-10 ${PRIVATE_URI}"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/robots hrp2-10-optimized ${PRIVATE_URI}"
    let "index= $index + 1"
  fi

  inst_array[index]="install_pkg $SRC_DIR/jrl jrl-walkgen ${JRL_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph-python ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas hpp-util ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/laas hpp-template-corba ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-core ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot dynamic-graph-corba ${LAAS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-tools ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-dynamic ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot soth ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-dyninv ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-application ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  # In groovy and hydro, use the standalone version of jrl_dynamics_urdf
  if [ "$ROS_VERSION" == "groovy" ] || [ "$ROS_VERSION" == "hydro" ]; then
    inst_array[index]="install_pkg $SRC_DIR/jrl jrl_dynamics_urdf ${LAAS_URI}"
    let "index= $index + 1"
  else
    inst_array[index]="install_ros_ws_package jrl_dynamics_urdf"
    let "index= $index + 1"
  fi

  inst_array[index]="install_pkg $SRC_DIR/sot sot-pattern-generator ${STACK_OF_TASKS_URI} master"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package dynamic_graph_bridge_msgs"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package dynamic_graph_bridge"
  let "index= $index + 1"

  inst_array[index]="install_ros_ws_package romeo_description"
  let "index= $index + 1"

  inst_array[index]="install_pkg $SRC_DIR/sot sot-romeo.git ${STACK_OF_TASKS_URI}"
  let "index= $index + 1"

  if [ "${IDH_PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_ros_ws_package hrp4_description"
    let "index= $index + 1"

    inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp4 ${IDH_PRIVATE_URI}"
    let "index= $index + 1"
  fi

  if [ "${PRIVATE_URI}" != "" ]; then
    inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp2 ${STACK_OF_TASKS_URI}"
    let "index= $index + 1"
  fi

  if [ "${PRIVATE_URI}" != "" ] || [ "${IDH_PRIVATE_URI}" != "" ]; then
    if ! [ "$GRX_3_0_FOUND" == "" ]; then

      inst_array[index]="install_ros_ws_package openhrp_bridge"
      let "index= $index + 1"

      inst_array[index]="install_ros_ws_package openhrp_bridge_msgs"
      let "index= $index + 1"

      inst_array[index]="install_pkg $SRC_DIR/sot sot-hrp2-hrpsys ${STACK_OF_TASKS_URI}"
      let "index= $index + 1"
    fi

    if ! [ "$GRX_3_1_FOUND" == "" ]; then
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

detect_grx
create_local_db

if (( DISPLAY_LIST_INSTRUCTIONS > 0 )); then
  display_list_instructions
  exit 0
fi

# Check number of arguments
EXPECTED_ARGS=2
if [ $# -ne $EXPECTED_ARGS ]
then
  warn "2 parameters are expected but" $# "have been passed"
  usage_message
  exit $E_BADARGS
else
  notice "Parameters found:" $1 $2
fi

install_level=$2

if [ $install_level -lt -1 ]; then
 exit 0
fi


################
# Installation #
################

if `test x"$SRC_DIR" = x`; then
    abort "Please set the source dir"
fi
if `test x"$INSTALL_DIR" = x`; then
    abort "Please set the install dir"
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

install_apt_dependencies()
{
	if [ $UPDATE_PACKAGE -eq 0 ]; then
	  return
	fi

	${SUDO} ${APT_GET_UPDATE}
	${SUDO} ${APT_GET_INSTALL} \
	build-essential \
	cmake pkg-config git \
	doxygen doxygen-latex \
	libltdl-dev liblog4cxx10-dev \
	libboost-all-dev \
	libeigen3-dev \
	liblapack-dev libblas-dev gfortran \
	python-dev python-sphinx python-numpy \
	omniidl omniidl-python libomniorb4-dev
	if ! [ $? -eq 0 ];  then
		exit -1
	fi
}

install_git()
{
    if [ $UPDATE_PACKAGE -eq 0 ]; then
        return
    fi

    #checking whether git is already installed.
    ${GIT} --version &> /dev/null
    if [ $? -eq 0 ];  then
      res=`${GIT} --version | awk ' { print $3 }'`
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

    echo 'git installation is finished.'
    echo ' Please do not forget to update the value of the variable GIT'
    echo ' in install_sot.sh'
}

install_doxygen()
{
    if [ $UPDATE_PACKAGE -eq 0 ]; then
        return
    fi

    #checking whether doxygen is already installed.
    ${DOXYGEN} --version &> /dev/null
    if [ $? -eq 0 ];  then
      res=`${DOXYGEN} --version | awk ' { print $1 }'`
      comp=`compare_versions "$res" "1.7.3"`
      if [[ $comp -ge 0 ]]; then
        # 'doxygen already installed'
        return
      else
        echo 'doxygen installed but with a deprecated version. Updating.'
      fi
    fi

    # get the dependencies.
    ${SUDO} ${APT_GET_INSTALL} flex bison
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

    echo 'doxygen installation is finished.'
    echo ' Please do not forget to update the value of the variable DOXYGEN'
    echo ' in install_sot.sh'
}

update_pkg()
{
    OLD_PWD=`pwd`

    # Update the remote repository reference
    if test -d "$2"; then
      cd $2
      ${GIT} fetch
    # Or make the first clone
    else
        ${GIT} clone ${GIT_CLONE_OPTS} $3/$2 $2
        cd $2
    fi

    # Switch to the branch if needed
    #  otherwise update it.
    if ! test x"$4" = x; then
       if ${GIT} branch | grep $4 ; then
          ${GIT} checkout $4
          ${GIT} pull ${GIT_OPTS}
       else
          ${GIT} checkout -b $4 origin/$4
       fi
    else
      ${GIT} pull ${GIT_OPTS}
    fi

    # Configure the repository
    ${GIT} submodule ${GIT_OPTS} init && ${GIT} submodule ${GIT_OPTS} update

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

    if [ $LOG_PACKAGE -eq 1 ]; then
        ${GIT} log -n 1 --pretty=oneline
        return
    fi

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
	-DCXX_DISABLE_WERROR=1 \
    	-DCMAKE_CXX_FLAGS=\"$local_cflags\" ..
    ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type="${LDFLAGS}" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
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
	${GIT} pull ${GIT_OPTS}
    else
	${GIT} clone ${GIT_CLONE_OPTS} "$3/$2"
	cd "$2"
    fi
    if ! test x"$4" = x; then
       if ${GIT} branch | grep "$4" ; then
	   ${GIT} checkout "$4"
       else
	   ${GIT} checkout -b "$4" "origin/$4"
       fi
    fi
    ${GIT} submodule ${GIT_OPTS} init && ${GIT} submodule ${GIT_OPTS} update
    python setup.py install --prefix=${INSTALL_DIR}
}

install_ros_legacy()
{
    if [ $UPDATE_PACKAGE -eq 0 ]; then
        return
    fi

    python_version=`python --version 2>&1 | awk '{print $2}'`
    comp=`compare_versions "$python_version" "2.7"`

    ${SUDO} sh -c 'echo "deb http://packages.ros.org/ros/ubuntu '$DISTRIB_CODENAME' main" > /etc/apt/sources.list.d/ros-latest.list'
    ${SUDO} chmod 644 /etc/apt/sources.list.d/ros-latest.list
    wget http://packages.ros.org/ros.key -O - | ${SUDO} apt-key add -
    ${SUDO} ${APT_GET_UPDATE}
    ${SUDO} ${APT_GET_INSTALL} python-setuptools python-pip
    ${SUDO} ${APT_GET_INSTALL} python-rosdep python-rosinstall python-rosinstall-generator
    if [ $comp -ge 0 ]; then
        ${SUDO} ${APT_GET_INSTALL} python-wstool
    fi
    ${SUDO} rosdep init || true 2> /dev/null > /dev/null # Will fail if rosdep init has been already run.
    rosdep update

    ${SUDO} ${APT_GET_INSTALL} ros-$ROS_VERSION-desktop-full
    ${SUDO} ${APT_GET_INSTALL} ros-$ROS_VERSION-pr2-mechanism      # for realtime_tools

    if [ "$ROS_VERSION" == "fuerte" ] || [ "$ROS_VERSION" == "electric" ]; then
        ${SUDO} ${APT_GET_INSTALL} ros-$ROS_VERSION-robot-model-py      # for parser urdf model in python   
    fi 

    if [ "$ROS_VERSION" == "fuerte" ]; then
      ${SUDO} ${APT_GET_INSTALL} ros-fuerte-robot-model
    fi


    if [ "$ROS_VERSION" == "groovy" ]; then
      ${SUDO} ${APT_GET_INSTALL} ros-groovy-control-msgs # for sot_pr2
    fi

    if [ "$ROS_VERSION" == "hydro" ]; then
      ${SUDO} ${APT_GET_INSTALL} ros-hydro-robot-state-publisher
      ${SUDO} ${APT_GET_INSTALL} ros-$ROS_VERSION-cmake-modules
      ${SUDO} ${APT_GET_INSTALL} ros-hydro-urdfdom-py    # for xml_reflection
    fi

    # install bullet (requires ros ppa)
    ${SUDO} ${APT_GET_INSTALL} 	libbullet-dev
}




# create a config file to load all env parameters
install_config_internal()
{
    # get python site packages path
    PYTHON_SITELIB=`python -c "import sys, os; print os.sep.join(['lib', 'python' + sys.version[:3], 'site-packages'])"`
    # get python dist packages path
    PYTHON_DISTLIB=`python -c "import sys, os; print os.sep.join(['lib', 'python' + sys.version[:3], 'dist-packages'])"`

    # load ros info
    source $SOT_ROOT_DIR/setup.bash

    # create the file
    CONFIG_FILE=$1

    echo "ROS_INSTALL_DIR=$INSTALL_DIR"             >> $CONFIG_FILE
    echo "export PATH=/opt/ros/$ROS_DISTRO/bin:\$PATH"        >> $CONFIG_FILE
    echo "export PYTHONPATH=\$ROS_ROOT/core/roslib/src:\$ROS_INSTALL_DIR/$PYTHON_SITELIB:\$ROS_INSTALL_DIR/$PYTHON_DISTLIB:\$PYTHONPATH" >> $CONFIG_FILE
    echo "export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib/pkgconfig:/opt/grx/lib/pkgconfig"     >> $CONFIG_FILE
    echo "export ROS_PACKAGE_PATH=\$ROS_WS_DIR:/opt/ros/${ROS_VERSION}/stacks:/opt/ros/\${ROS_VERSION}/stacks/ros_realtime:\$ROS_PACKAGE_PATH" >> $CONFIG_FILE
    echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib/plugin:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
    echo "export LD_LIBRARY_PATH=\$ROS_INSTALL_DIR/lib:\$LD_LIBRARY_PATH" >> $CONFIG_FILE
    echo "export ROS_MASTER_URI=http://localhost:11311" >> $CONFIG_FILE
}


install_config()
{
    # load ros info
    source $SOT_ROOT_DIR/setup.bash

    # create the file
    CONFIG_FILE=config_$ROS_DEVEL_NAME.sh
    echo "#!/bin/sh"   >  $CONFIG_FILE
    echo ". $SOT_ROOT_DIR/setup.sh" >> $CONFIG_FILE
    install_config_internal $CONFIG_FILE

    # create the file
    CONFIG_FILE=config_$ROS_DEVEL_NAME.bash
    echo "#!/bin/bash"   >  $CONFIG_FILE
    echo "source $SOT_ROOT_DIR/setup.bash" >> $CONFIG_FILE
    install_config_internal $CONFIG_FILE
}


# install all ros stack required
install_ros_ws()
{
    if [ $UPDATE_PACKAGE -eq 0 ]; then
        return
    fi

    # The master branch is for the current ROS development release
    # (Hydro). All the oldest releases are named by their release name:
    # fuerte, groovy, etc.
    gh_ros_sub_dir=master
    if `! test x$ROS_VERSION == xhydro`; then
	gh_ros_sub_dir=$ROS_VERSION
    fi
    
    echo "Version to be installed: $ROS_VERSION"

    wget  https://raw.github.com/laas/ros/$gh_ros_sub_dir/laas.rosinstall  --output-document=/tmp/laas.rosinstall
    cat  /tmp/laas.rosinstall  > /tmp/sot_$ROS_VERSION.rosinstall

    if [ "${PRIVATE_URI}" != "" ]; then
      wget  https://raw.github.com/laas/ros/$gh_ros_sub_dir/jrl-umi3218-private.rosinstall   --output-document=/tmp/jrl-umi3218-private.rosinstall
      cat  /tmp/jrl-umi3218-private.rosinstall >> /tmp/sot_$ROS_VERSION.rosinstall
    fi

    if [ "${TRAC_LAAS_URI}" != "" ]; then
      wget  https://raw.github.com/laas/ros/$gh_ros_sub_dir/laas-private.rosinstall   --output-document=/tmp/laas-private.rosinstall
      cat  /tmp/laas-private.rosinstall >> /tmp/sot_$ROS_VERSION.rosinstall
    fi

    if [ "${IDH_PRIVATE_URI}" != "" ]; then
      echo -e "- git:\n    uri: git@idh.lirmm.fr:mcp/ros/hrp4/hrp4_urdf.git\n" \
           "   local-name: stacks/hrp4\n    version: "${ROS_VERSION} > /tmp/idh-private.rosinstall
      cat  /tmp/idh-private.rosinstall >> /tmp/sot_$ROS_VERSION.rosinstall
    fi

    rosinstall $SOT_ROOT_DIR /tmp/sot_$ROS_VERSION.rosinstall /opt/ros/$ROS_VERSION
}

install_ros_ws_package()
{
    if [ $LOG_PACKAGE -eq 1 ]; then
        roscd $1
        ${GIT} log -n 1 --pretty=oneline
        return
    fi

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
    	-DCMAKE_CXX_FLAGS=\"$local_cflags\" ..
    ${CMAKE} \
	-DCMAKE_BUILD_TYPE=$local_build_type \
	-DCMAKE_EXE_LINKER_FLAGS_$local_build_type="${LDFLAGS}" \
	-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
	-DCMAKE_CXX_FLAGS="$local_cflags" ..
    ${MAKE} ${MAKE_OPTS}
    
    # for groovy
    if [ "$ROS_VERSION" == "groovy" ]; then
        if [ "$1" == "urdf_parser_py" ] || [ "$1" == "robot_capsule_urdf" ] || [ "$1" == "xml_reflection" ]; then
            ${MAKE} install
        fi
    fi

    # for hydro
    if [ "$ROS_VERSION" == "hydro" ]; then
        if [ "$1" == "robot_capsule_urdf" ]; then
            ${MAKE} install
        fi
    fi

    # for all distribution
    if [ "$1" == "dynamic_graph_bridge" ] || [ "$1" == "openhrp_bridge" ] ; then
        ${MAKE} install
    fi
}

update_ros_setup()
{
  echo "update ros setup"

  # Setup ROS variables
  if [ ! -d /opt/ros/$ROS_VERSION ]; then
    echo "ROS_VERSION $ROS_VERSION does not appear to be installed"
    exit 1
  fi

  if [ -f $SOT_ROOT_DIR/setup.bash ]; then
    source $SOT_ROOT_DIR/setup.bash
  fi
}


# Setup environment variables.
if ! [ "$GRX_3_1_FOUND" == "" ]; then
  export PKG_CONFIG_PATH="/opt/grx/lib/pkgconfig/":$PKG_CONFIG_PATH
fi

export PKG_CONFIG_PATH="${INSTALL_DIR}/lib/pkgconfig":$PKG_CONFIG_PATH

run_instructions()
{
  echo "run instructions from $install_level to ${#inst_array[@]}"
  for ((lindex=$install_level; lindex<${#inst_array[@]} ; lindex++ ))
  do
      echo
      if [ $lindex -ge 4 ]; then
        update_ros_setup
      fi

      echo "Eval ("$lindex"):" ${inst_array[$lindex]}
      ${inst_array[$lindex]}
  done
}

run_instructions
exit 0


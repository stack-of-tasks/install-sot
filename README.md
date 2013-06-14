install-sot
===========
Bash script to install the repositories of Stack Of Tasks

Quick Start
===========

To start the installation, you should
1/ Set your version of ROS
2/ Set your LAAS user account (optional)
3/ call:
install_sot.sh ros-unstable level_to_start

If ros is installed, as well as git and doxygen,
you can start with level_to_start=3.
Otherwise you can set level_to_start to 0 for installing
the needed packages.

This will install a ros workspace in
$HOME/devel/ros-unstable/

All the stacks will be installed in 
$HOME/devel/ros-unstable/stacks

The repositories will be cloned in :
$HOME/devel/ros-unstable/src

The installation will then done in:
$HOME/devel/ros-unstable/install

Usage
=====

Usage: `basename $0` [-h] ros_subdir installation_level
    ros_subdir: The sub directory where to install the ros workspace.
      The script creates a variable ros_install_path from ros_subdir:
      ros_install_path=$HOME/devel/$ros_subdir
      The git repositories are cloned in ros_install_path/src and
      installed in ros_install_path/install.
  
    installation_level: Specifies at which step the script should start
      the installation.
  
  Options:
     -h : Display help
     -l : Display the steps where the script can be started for installing.
          This also display the internal instructions run by the script.
          To use -l you HAVE TO specify ros_install_path and installation_level.
          With -l the instructions are displayed but not run.
     -g : OpenHRP 3.0.7 has a priority than OpenHRP 3.1.0. Default is the reverse.
     -m : Compile the sources without updating them
     -u : Update the sources without compiling them

LAAS_USER_ACCOUNT
=================
If you have a laas account, which is also a github account, you have to set 
the LAAS_USER_ACCOUNT variable to have read-write access to the repositories.

Deployment:
==========
rsync -avz $HOME/devel/ros-unstable username@robotc:./devel/

will copy the overall control architecture in
the home directory of username in computer robotc (could be hrp2c).


Requirements:
=============
gfortran
lapack
ros-pr2-controllers
omniidl


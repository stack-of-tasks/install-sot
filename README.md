install-sot
===========

[![Build Status](https://travis-ci.org/stack-of-tasks/install-sot.png?branch=master)](https://travis-ci.org/stack-of-tasks/install-sot)

This script install automatically the Stack of Tasks and its
dependencies.

Quick Start
-----------

Please be aware that not setting correctly your environment variables may lead to numerous problems.

To start the installation, you should:

 1. Set your version of ROS

 For instance for electric and using the subdirectory ros-unstable-test, it will be:
 ROS_ROOT=/opt/ros/electric/ros
 ROS_PACKAGE_PATH=/home/user/devel/ros-unstable-test:/opt/ros/electric/stacks:/opt/ros/electric/stacks/ros_realtime:/opt/ros/electric/stacks
 ROS_MASTER_URI=http://localhost:11311
 
 1. Set your private repositories account (optional, but VERY important):

 GITHUB_ACCOUNT,
 PRIVATE_URI

 1. Call:

```sh
install_sot.sh ros_subdir installation_level
```

If ROS is installed, as well as Git and Doxygen, you can start with
`installation_level=3`.

Otherwise you can set `install_level` to 0 to install the required
dependencies.
Note that the steps 0, 2 and 3 require super user privileges, to install ros and 
distribution dependencies.

**Do not** run the script install_sot.sh in sudo, this will create some problems.

This will install a ROS workspace in `$HOME/devel/ros_subdir/`.

The stacks will be installed in `$HOME/devel/ros_subdir/stacks`.

The repositories will be cloned in: `$HOME/devel/ros_subdir/src`

The installation will then done in: `$HOME/devel/ros_subdir/install`

Be aware that if you started the install with some wrong environment variables, 
the link to the repositories will be kept in 
$HOME/devel/ros_subdir/.rosinstall
Please remove this file before running again the script with your new variables.

Usage
-----

```
Usage: `basename $0` [-h] ros_subdir installation_level
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
   -g : OpenHRP 3.0.7 has a priority than OpenHRP 3.1.0. Default is the reverse.
   -m : Compile the sources without updating them
   -u : Update the sources without compiling them
   
  Environment variables:
   GITHUB_ACCOUNT: If you  have a github user account you should set the environment variable
                   GITHUB_ACCOUNT to have read-write rights on the repositories 
                   otherwise they will be uploaded with read-only rights.
   PRIVATE_URI: If you have access to the private repositories for the HRP2.
                Please uncomment the line defining PRIVATE_URI.
   IDH_PRIVATE_URI: If you have access to the private repositories for the HRP4.
                Please uncomment the line defining IDH_PRIVATE_URI.
```

Deployment:
-----------

```sh
rsync -avz $HOME/devel/ros_subdir username@robotc:./devel/
```

will copy the overall control architecture in
the home directory of username in computer robotc (could be hrp2c).


3rd party dependencies:
-----------------------

The following external software are required (and will be installed
automatically by step 0):

 - gfortran
 - lapack
 - ros-pr2-controllers
 - omniidl

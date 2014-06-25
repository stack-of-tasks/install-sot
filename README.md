install-sot
===========

[![Build Status](https://travis-ci.org/stack-of-tasks/install-sot.png?branch=master)](https://travis-ci.org/stack-of-tasks/install-sot)

This script install automatically the Stack of Tasks and its
dependencies.

Quick Start
-----------

Please be aware that not setting correctly your environment variables may lead to numerous problems.

To start the installation, you should:
 
 1. Set your private repositories account (optional, but VERY important):
 In the install_sot.sh file, uncomment the lines starting by those words if you 
  have access to those private repositories.

 GITHUB_ACCOUNT,
 IDH_PRIVATE_URI,
 PRIVATE_URI

 1. Call:

```sh
install_sot.sh -r ros_distro ros_subdir installation_level
```

This script installs all the stack of tasks packages as well as the system dependencies
and the selected ros distribution.

- ros_distro is the chosen ros distribution
To avoid typing the ros distribution every time in the command line, you 
can add it in the install_sot.sh file:
`ROS_VERSION=hydro`

- ros_subdir indicates the workspace: `$HOME/devel/ros_subdir/`
 - The stacks will be installed in `$HOME/devel/ros_subdir/stacks`
 - The repositories will be cloned in: `$HOME/devel/ros_subdir/src`
 - The installation will then done in: `$HOME/devel/ros_subdir/install`

- installation_level indicates the start level for the installation.

You can set `install_level` to `0` to install the required dependencies (ros included)

If ROS is installed, as well as Git and Doxygen, you can start with `installation_level=3`.

Note that the steps 0, 2 and 3 require super user privileges, to install ros and 
distribution dependencies.

**Do not** run the script `install_sot.sh` in sudo, this will create some problems.

Running `./install_sot.sh [-r ros_distro] -l` displays the list of packages 
that will be installed, preceeded by their installation_level


Be aware that if you started the install with some wrong environment variables, 
the link to the repositories will be kept in 
`$HOME/devel/ros_subdir/.rosinstall`
Please remove this file before running again the script with your new variables.

Usage
-----

```
Usage: ./install_sot.sh [-h] ros_subdir installation_level
    ros_subdir: The sub directory where to install the ros workspace.
      The script creates a variable ros_install_path from ros_subdir:
      ros_install_path=$HOME/devel/$ros_subdir
      The git repositories are cloned in ros_install_path/src and
      installed in ros_install_path/install.

    installation_level: Specifies at which step the script should start
      the installation.

  Options:
   -h : Display help.
   -r ros_release : Specifies the ros release to use. If not specified in 
        the ```install_sot.sh``` file, it needs to be given in command line
   -l : Display the steps where the script can be started for installing.
        This also display the internal instructions run by the script.
        To use -l you HAVE TO specify ros_install_path and installation_level.
        With -l the instructions are displayed but not run.
   -m : Compile the sources without updating them
   -c : Remove the cmake cache of the packages compiled (needs -c)
   -o : print the git log of every package compiled and exit.
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

By default, this script runs is executed with both `-u` (update) and `-m` (make) 
options: it will clone/update then make each of the package listed.

By specifying the `-u` (resp `-m`) option, all the packages will *only* be installed/
updated (resp. compiled).

e.g.
```./install_sot.sh -mc ros 0```
will compile and install every package (they must have been cloned beforehands),
while removing the cmake cache before every compilation.

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

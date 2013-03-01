install-sot
===========

Bash script to install the repositories of Stack Of Tasks

To start the installation, you should
1/ Set your LAAS user account
2/ call:
install_sot.sh ros-unstable 0

This will install a ros workspace in
$HOME/devel/ros-unstable/

All the stacks will be installed in 
$HOME/devel/ros-unstable/stacks

The repositories will be cloned in :
$HOME/devel/ros-unstable/src

The installation will then done in:
$HOME/devel/ros/install


Deployment:
==========
rsync -avz $HOME/devel/ros-unstable username@robotc:./devel/

will copy the overall control architecture in
the home directory of username in computer robotc (could be hrp2c).

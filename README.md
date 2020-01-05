# roger-skyline-1
Roger Skyline 1


The deployment script deploy.sh can be run after the prerequisites are met, which are:

1) A VM has been created using Virtualbox with the settings stated above.
2) The VM network is set to Bridged Adapter.
3) sudo has been set up for the user.
4) Git is installed on the VM ("$ apt-get install git" as root)
Clone the repository to the VM:

git clone https://github.com/kraskp/roger-skyline-1
Execute the deployment script (must be done with sudo):

$ chmod +x ./deploy.sh
$ sudo ./deploy.sh
Test that the deployment went fine by logging in to 10.12.124.124/index.html on the host machine browser.

To get a checksum of the VM disk, go to /home/admin/VirtualBox VMs/, select the VM and then run:

$ shasum < [vdi file]

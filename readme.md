# SecureAuth Docker

Dockerfied SecureAuth Intelligent Identity Cloud allows you to quickly setup and deploy a containerized SecureAuth server.

The following environment variables are supported
*   `sa_version` - The SecureAuth Intelligent Identity Cloud version to deploy. The default is 19.07.
*   `sa_key` - The SecureAuth Activation Code for your deployment.

---

Not included in this repo:
- Please contact SecureAuth support for the idp.zip file

---

SecureAuth Docker is a Windows container, and as such requires to be run against Docker on Windows. For non-Windows users,
using Vagrant (https://www.vagrantup.com) 

Reference: https://github.com/StefanScherer/windows-docker-machine

* `git clone https://github.com/StefanScherer/windows-docker-machine` - clone project to start
* `cd windows-docker-machine` - change directory
* `vagrant up --provider vmware_desktop 2016-box` - use --provider vmware_desktop if using VMWware. 2016-box is prebuilt from Vagrant Cloud.
* `docker context ls` - list your new Docker machine
* `docker context use 2016-box` - switch to Windows containers
* `docker version` - validate Docker client is talknig to Windows Docker engine

---

Example build:
* `docker build -t your/image .`

Example execution:
* `docker run -d -p 80:80 -p 443:443 --name secureauth -e sa_key='your_code_here' your/image:latest`

---


* https://secureauth.com
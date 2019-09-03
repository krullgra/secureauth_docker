# SecureAuth Docker

Dockerfied SecureAuth Intelligent Identity Cloud allows you to quickly setup and deploy a containerized SecureAuth server.

The following environment variables are supported
*   `sa_version` - The SecureAuth Intelligent Identity Cloud version to deploy. The default is 19.07.
*   `sa_key` - The SecureAuth Activation Code for your deployment.

---

Not included in this repo:
- Please contact SecureAuth support for the idp.zip file

---

Example build:
* `docker build -t your/image .`

Example execution:
* `docker run -d -p 80:80 -p 443:443 --name secureauth -e sa_key='your_code_here' your/image:latest`

---


* https://secureauth.com
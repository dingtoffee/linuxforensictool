# Linux Forensic Tools

Resources related to Linux Forensic are very limited. I have created a list of tools and presentations I found useful for Linux/Docker Forensic/Incident response. I have also listed down automation scripts I created to faciliate the forensic artifacts extraction. 

## Linux Live Triage 
1. [R-CSIRT Linux Triage Tool](https://github.com/Recruit-CSIRT/LinuxTriage "R-CSIRT Linux Triage Tool") - A script used to obtain linux artifacts from Live system 
2. [FastIR Collector Linux](https://github.com/SekoiaLab/Fastir_Collector_Linux "FastIR Collector Linux")

## Presentation 
1. [Ali Hadi - Performing Linux Forensic Analysis and Why You Should care](https://www.osdfcon.org/presentations/2019/Ali-Hadi_Performing-Linux-Forensic-Analysis-and-Why-You-Should-Care.pdf)

## Evidence Collection on Cloned Image 
1. [Linux Triage Collector](https://github.com/dingtoffee/linuxforensictool/blob/main/Linux%20Triage/linux_triage.sh) A script I modified based on R-CSIRT Linux Triage Tool to extract important evidence from a cloned image instead of live system. It also has a built in function to build a timeline of ext4 filesystem which is important for Linux FileSystem analysis. 
2. [Docker Forensic Toolkit](https://github.com/docker-forensics-toolkit/toolkit) - A framework that could be used to extract docker related artifacts from a cloned linux image. 
3. [Docker Forensic Aritfacts Generator](https://github.com/dingtoffee/linuxforensictool/blob/main/Docker%20Forensic/dockerforensic) - To automate the artifacts generation from docker system. I have created a script to automate the extraction using Docker Forensic Toolkit. 

## Linux Triage Collector 
It is a script modified based on the R-CSIRT to collect important artifacts from a forensic image. It will be able to help you pull artifacts including: 
- Logs under /var/log 
- BTMP/WTMP/UTMP 
- User Profile
- System Information 
- Timeline of Filesystem (optional) 

### Usage 
1. To mount the hard disk onto your linux platform 
``` 
mkdir /mnt/disc
mount -o ro,loop <image> /mnt/disc
```
2. Use the script to extract relevant evidence 

Example 1: To get the artifacts excluding timeline
```
usage: sudo ./linux_triage.sh /mnt/disc
```
Example 2: To get the artifacts including timeline - This will provide a bodyfile of the filesystem. You could use other tools to turn bodyfile into ASCII.
```
usage: sudo ./linux_triage.sh /mnt/disc 1
```
## Docker Forensic Aritfacts Generator
If you have too many Dockers inside your cloned image and would like to automate the artfacts generation process. 
1. Place the [DOF](https://github.com/dingtoffee/linuxforensictool/blob/main/Docker%20Forensic/dof) binary under /bin. I have downloaded a stable version from the [Docker Forensic Toolkit](https://github.com/docker-forensics-toolkit/toolkit).
2. Use the script to automate the artifacts generation:
- Docker Container Log 
- Timeline of Docker FileSystem 
### Usage 
 ``` 
 docker-script.sh [docker-path] [Timeline_Start_Date(YYYY-MM-DD)] [Timeline_End_Date(YYYY-MM-DD)
```

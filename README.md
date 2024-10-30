# KubeEdge on MicroK8s

![](https://i.imgur.com/waxVImv.png)
### [View all Roadmaps](https://github.com/nholuongut/all-roadmaps) &nbsp;&middot;&nbsp; [Best Practices](https://github.com/nholuongut/all-roadmaps/blob/main/public/best-practices/) &nbsp;&middot;&nbsp; [Questions](https://www.linkedin.com/in/nholuong/)
<br/>

This repo is WIP (Work In Progress) as of now

Its aim is to provide a fully automated install of the KubeEdge components on 2 separate Google Cloud Engine (GCE) instances: 1 for CloudCore 
and for EdgeCore.

Currently working on a solution for [issue #2362](https://github.com/nholuongut/microk8s-kubeedge/issues/2362)
**[UPDATE]** Solution has been provided by the KubeEdge team: the initial security token must be obtained via 'keadm gettoken' on cloud side (after 'keadm init') 
and then used on edge side in keadm init 'via --token='. The latest version [microk8s-kubeedge.sh](https://github.com/nholuongut/microk8s-kubeedge/blob/main/sh/microk8s-kubeedge.sh) 
integrates this additional code.

If you wanna dig into the details [issue #2362](https://github.com/nholuongut/microk8s-kubeedge/issues/2362):

1. Structured log of failing execution is [here](https://github.com/nholuongut/microk8s-kubeedge/runs/1442253504) when you're signed in with your GitHub account
2. Raw log of failing execution is accessible via top right menu of the page linked in previous bullet : go to "..." > View Raw Logs
3. Shell script generating those logs is [microk8s-kubeedge.sh](https://github.com/nholuongut/microk8s-kubeedge/blob/main/sh/microk8s-kubeedge.sh)

For further details, please, check the official Git [repository of KubeEdge](https://github.com/nholuongut/microk8s-kubeedge)

Feel free to fork and reuse this repo already. But, rather come back until we get it to work to obtain complete version.

# 🚀 I'm are always open to your feedback.  Please contact as bellow information:
### [Contact ]
* [Name: nho Luong]
* [Skype](luongutnho_skype)
* [Github](https://github.com/nholuongut/)
* [Linkedin](https://www.linkedin.com/in/nholuong/)
* [Email Address](luongutnho@hotmail.com)

![](https://i.imgur.com/waxVImv.png)
![](Donate.png)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/nholuong)

# License
* Nho Luong (c). All Rights Reserved.🌟

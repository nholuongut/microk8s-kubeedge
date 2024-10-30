#!/bin/bash

#https://github.com/kubeedge/kubeedge/issues/2357

#https://linuxconfig.org/how-to-disable-ipv6-address-on-ubuntu-18-04-bionic-beaver-linux
#https://www.configserverfirewall.com/ubuntu-linux/ubuntu-disable-ipv6/
#https://itsfoss.com/disable-ipv6-ubuntu-linux/
#cat /proc/sys/net/ipv6/conf/all/disable_ipv6
#https://bugs.launchpad.net/ubuntu/+source/linux/+bug/1771222

set -e
trap 'catch $? $LINENO' EXIT
catch() {
  if [ "$1" != "0" ]; then
    echo "Error $1 occurred on $2"
  fi
}

REPORT='report.md'

OS=$(uname -a)
echo "$OS" > "$REPORT"
if [[ "$OS" == 'Linux'* ]]
then
   lsb_release -a | tee "$REPORT"
fi

TOTAL_STEPS=2
SCRIPT_COMPLETED='<-<script-completed>->'
STEP_COMPLETED='<-<step-completed>->'


ON_GCE=$((curl -s -i metadata.google.internal | grep 'Google') || true)

echo -e " "
# variables below can be inherited from environment
if [[ -z ${GCP_PROJECT+x} && ! "$ON_GCE" == *'Google'* ]]     ; then echo "ERROR: gcp project not set" && false ; fi
if [[ -z ${GCP_ZONE+x} ]]                                     ; then GCP_ZONE='us-central1-c'                   ; fi ; echo "gcp zone: $GCP_ZONE"

if [[ -z ${KE_GCE_CREATE+x} ]]                                ; then KE_GCE_CREATE='true'                       ; fi ; echo "kubeedge gce create: $KE_GCE_CREATE"
if [[ -z ${KE_GCE_DELETE+x} ]]                                ; then KE_GCE_DELETE='false'                      ; fi ; echo "kubeedge gce delete: $KE_GCE_DELETE"

if [[ -z ${KE_EDGE+x} ]]                                      ; then KE_EDGE='true'                             ; fi ; echo "kubeedge install edge: $KE_EDGE"
if [[ -z ${KE_CLOUD+x} ]]                                     ; then KE_CLOUD='true'                            ; fi ; echo "kubeedge install cloud: $KE_CLOUD"
if [[ -z ${KE_TEMP_MAPPER+x} ]]                               ; then KE_TEMP_MAPPER='true'                      ; fi ; echo "kubeedge temp mapper: $KE_TEMP_MAPPER"

if [[ -z ${KE_VERSION+x} ]]                                   ; then KE_VERSION='v1.5.0'                        ; fi ; echo "kubeedge version: $KE_VERSION"
if [[ -z ${KE_CLOUD_PORT+x} ]]                                ; then KE_CLOUD_PORT='10000'                      ; fi ; echo "kubeedge cloud port: $KE_CLOUD_PORT"

if [[ -z ${KE_IMAGE_FAMILY+x} ]]                              ; then KE_IMAGE_FAMILY='ubuntu-2004-lts'          ; fi ; echo "kubeedge image family: $KE_IMAGE_FAMILY"
if [[ -z ${KE_IMAGE_PROJECT+x} ]]                             ; then KE_IMAGE_PROJECT='ubuntu-os-cloud'         ; fi ; echo "kubeedge image project: $KE_IMAGE_PROJECT"
if [[ -z ${KE_CLOUD_NODE+x} ]]                                ; then KE_CLOUD_NODE='microk8s-ke-cloud'          ; fi ; echo "cloud instance name : $KE_CLOUD_NODE"
if [[ -z ${KE_EDGE_NODE+x} ]]                                 ; then KE_EDGE_NODE='microk8s-ke-edge'            ; fi ; echo "edge instance name: $KE_EDGE_NODE"
if [[ -z ${MK8S_VERSION+x} ]]                                 ; then MK8S_VERSION='1.19'                        ; fi ; echo "microk8s version: $MK8S_VERSION"
echo -e " "

create_gce_instance() 
{
  local GCE_INSTANCE="$1"
  local GCE_IMAGE_FAMILY="$2"
  local GCE_IMAGE_PROJECT="$3"
  GCE_IMAGE=$(gcloud compute images describe-from-family "$GCE_IMAGE_FAMILY"  --project="$GCE_IMAGE_PROJECT" --format="value(name)")
  echo -e "\n### setup instance: $GCE_INSTANCE - image: $GCE_IMAGE - image family: $GCE_IMAGE_FAMILY - image project: $GCE_IMAGE_PROJECT"
  if [[ ! $(gcloud compute instances list --project="$GCP_PROJECT") == *"$GCE_INSTANCE"* ]]
  then 
    gcloud compute instances create \
        --machine-type='n1-standard-2' \
        --image-project="$GCE_IMAGE_PROJECT" \
        --image="$GCE_IMAGE" \
        --zone="$GCP_ZONE" \
        --project="$GCP_PROJECT" \
        "$GCE_INSTANCE"
  fi
  gcloud compute instances list --project="$GCP_PROJECT" | tee "$REPORT"
  while [[ ! $(gcloud compute ssh "$GCE_INSTANCE" --command='uname -a' --zone="$GCP_ZONE" --project="$GCP_PROJECT") == *'Linux'* ]]
  do
    echo -e "instance not ready for ssh..."
    sleep 5 
  done
  gcloud compute ssh "$GCE_INSTANCE" \
      --command='uname -a'  \
      --zone="$GCP_ZONE" \
      --project="$GCP_PROJECT"
}

if [[ $KE_GCE_CREATE == 'true' ]]
then

  KE_CLOUD_IP_TAG='ke-cloud-ip:'
  KE_CLOUD_IP=''
  KE_SECURITY_TOKEN_TAG='ke-security-token:'
  KE_SECURITY_TOKEN=''
  
  declare -a KE_INSTANCES=("$KE_CLOUD_NODE" "$KE_EDGE_NODE")
  
  if [[ ! "$ON_GCE" == *'Google'* ]]
  then

    for KE_INSTANCE in "${KE_INSTANCES[@]}"
    do
  
      echo -e "### SETUP OF INSTANCE: $KE_INSTANCE"
        
      echo -e "\n### NOT on GCE\n" 
  
      create_gce_instance "$KE_INSTANCE" "$KE_IMAGE_FAMILY" "$KE_IMAGE_PROJECT"
      
      gcloud compute ssh "$KE_INSTANCE" --command='sudo rm -rf /var/lib/apt/lists/* && (sudo apt update -y || sudo apt update -y) && sudo apt upgrade -y && sudo apt autoremove  -y' --zone="$GCP_ZONE" --project="$GCP_PROJECT"
      gcloud compute scp "$0"  "$KE_INSTANCE:$(basename $0)" --zone="$GCP_ZONE" --project="$GCP_PROJECT"
      #gcloud compute scp "$(dirname $0)/ke-device-simulator.sh" "$KE_INSTANCE:ke-device-simulator.sh" --zone $GCP_ZONE --project=$GCP_PROJECT
      gcloud compute ssh "$KE_INSTANCE" --command="sudo chmod ugo+x ./$(basename $0)" --zone="$GCP_ZONE" --project="$GCP_PROJECT"
      #gcloud compute ssh "$KE_INSTANCE" --command='sudo chmod ugo+x ke-device-simulator.sh' --zone "$GCP_ZONE" --project="$GCP_PROJECT"
      
      I=0
      STEP=1
      STEP_REPORT="ke-step-report-$STEP.log" && rm "$STEP_REPORT" && touch "$STEP_REPORT"
      while [[ ! $(cat "$STEP_REPORT" | grep "$SCRIPT_COMPLETED") && $I -lt 5 ]]
      do
        I=$((I+1))
        echo -e "\n### triggering script step: $STEP  - iteration: $I - instance: $KE_INSTANCE"
        gcloud compute ssh "$KE_INSTANCE" --command="bash ./$(basename $0) $STEP $I $KE_INSTANCE $KE_CLOUD_IP $KE_SECURITY_TOKEN" --zone="$GCP_ZONE" --project="$GCP_PROJECT" | tee -a "$STEP_REPORT"
        if [[ $(cat "$STEP_REPORT" | grep "$STEP_COMPLETED $STEP") ]]
        then
          if [[ "$STEP" -lt "$TOTAL_STEPS" ]]
          then
            STEP=$((STEP+1))
            STEP_REPORT="ke-step-report-$STEP.log" && rm "$STEP_REPORT" && touch "$STEP_REPORT"
          fi
        fi
        if [[ ! -z $(cat "$STEP_REPORT" |  grep "$KE_CLOUD_IP_TAG") ]]
        then
           KE_CLOUD_IP=$(cat "$STEP_REPORT" | grep "$KE_CLOUD_IP_TAG" | awk '{print $2}')
           echo -e "ke cloud ip set to: $KE_CLOUD_IP (instance: $KE_INSTANCE - step: $STEP - iteration: $I)"
        fi
        if [[ ! -z $(cat "$STEP_REPORT" |  grep "$KE_SECURITY_TOKEN_TAG") ]]
        then
           KE_SECURITY_TOKEN=$(cat "$STEP_REPORT" | grep "$KE_SECURITY_TOKEN_TAG" | awk '{print $2}')
           echo -e "ke security token set to: $KE_SECURITY_TOKEN (instance: $KE_INSTANCE - step: $STEP - iteration: $I)"
        fi
        while [[ ! $(gcloud compute ssh "$KE_INSTANCE" --command='uname -a' --zone="$GCP_ZONE" --project="$GCP_PROJECT") == *'Linux'* ]]
        do
          echo -e "instance not ready for ssh..."
          sleep 5s 
        done
      done
      
      cat "$STEP_REPORT" | grep "$SCRIPT_COMPLETED"  > /dev/null
      rm 'ke-step-report'*
      
    done
    
    exit 0

  fi 
  
fi

#gcloud compute ssh microk8s-ke-cloud --zone 'us-central1-c' --project=$GCP_PROJECT
#gcloud compute ssh microk8s-ke-edge --zone 'us-central1-c' --project=$GCP_PROJECT
#gcloud compute scp 'docker/Dockerfile-snapd'  'microk8s-kubedge:Dockerfile-snapd' --zone 'us-central1-c' --project=$GCP_PROJECT

echo -e "\n### running on GCE\n"

#to allow both sides of kube edge on 1 test machine
#as per https://kubeedge.slack.com/archives/CDXVBS085/p1605672335180100
#export CHECK_EDGECORE_ENVIRONMENT='false'

KE_INTERNAL_IP=$(hostname -I | awk '{print $1}')
KE_EXTERNAL_IP=$(curl --silent http://ifconfig.me)

KE_OS='linux'
KE_ARCH='amd64'
#/home/ddurand/keadm-v1.4.0-linux-amd64/keadm/keadm
KE_ADM="keadm-$KE_VERSION-$KE_OS-$KE_ARCH/keadm/keadm"
cd 
if [[ -z $(cat .bashrc | grep "$KE_ADM") ]]
then
  alias keadm="$HOME/$KE_ADM" 
  echo "alias keadm='$HOME/$KE_ADM'" >> .bashrc
fi

[[ -d '.kube' ]] || (mkdir '.kube' && sudo mkdir '/root/.kube')
KUBE_CONFIG="$HOME/.kube/config"
KUBE_ROOT_CONFIG='/root/.kube/config'
sudo rm -f "$KUBE_ROOT_CONFIG"
[[ -f "$KUBE_CONFIG" ]] || (touch "$KUBE_CONFIG" && sudo touch "$KUBE_ROOT_CONFIG")

exec_step1()
{
  local STEP="$1"
  local KE_INSTANCE="$2"
  
  sudo apt update -y && sudo apt install -y net-tools
  
  if [[ ! -f "$KE_ADM" ]]
  then
    echo -e "\n### install keadm client:"
	  wget --quiet "https://github.com/kubeedge/kubeedge/releases/download/$KE_VERSION/keadm-$KE_VERSION-$KE_OS-$KE_ARCH.tar.gz"
    tar -xf keadm-"$KE_VERSION-$KE_OS-$KE_ARCH.tar.gz"
  fi
  
  $KE_ADM version | grep "$KE_VERSION"

  if [[ "$KE_INSTANCE" == *'edge'* ]]
  then

    if [[ -z $(which mqtt) ]]
    then
     # echo -e "\n### install mqtt client:"
     # wget --quiet https://github.com/hivemq/mqtt-cli/releases/download/v4.4.2/mqtt-cli-4.4.2.deb
     # sudo apt install -y ./mqtt-cli-4.4.2.deb
     true
    fi
  
    if [[ -z $(which mosquitto_sub) ]]
    then
      echo -e "\n### install mosquitto-clients:"
      sudo apt install -y mosquitto-clients
    fi
  
    if [[ -z $(which docker) ]]
    then
      echo -e "\n### install docker: "
      sudo snap install docker
      sudo snap list | grep 'docker'
      sudo snap disable docker
      sudo groupadd docker || true
      sudo usermod -aG docker "$USER"
      sudo snap enable docker
      sudo snap start --enable docker
      sudo docker version
      echo -e "groups for $USER: $(groups $USER)"
    fi
  fi
  
  if [[ "$KE_INSTANCE" == *'cloud'* ]]
  then
  
    #which 'cloudcore' > null
    #echo -e "\n### cloudcore path: $(which 'cloudcore')"
    
    if [[ -z $(which microk8s) ]]
    then
      echo -e "\n### install microk8s: "
      #sudo snap install microk8s --classic --channel="$MK8S_VERSION"
      sudo snap install microk8s --classic --edge
      sudo snap list | grep 'microk8s'
      sudo microk8s status --wait-ready
      sudo usermod -a -G 'microk8s' "$USER"
      sudo chown -f -R "$USER" ~/.kube
    fi
  fi
  
  echo -e "$STEP_COMPLETED $STEP on $KE_INSTANCE"
  
  if [[ -f /var/run/reboot-required ]]
  then
    echo 'WARNING: reboot required. Reboot in 2s...'
    sleep 2s
    sudo reboot
  fi
}

exec_step2()
{
  local STEP="$1"
  local KE_INSTANCE="$2"
  local KE_CLOUD_IP="$3"
  local KE_SECURITY_TOKEN="$4"
  
  if [[ "$KE_INSTANCE" == *'edge'* ]]
  then
  
    echo -e "### check connectivity to cloud core @ $KE_CLOUD_IP from $KE_INTERNAL_IP:"
    ping -c 5 "$KE_CLOUD_IP"
  
    echo -e "\n### docker version:"
    docker version
    
    if [[ ! -f /etc/kubeedge/config/edgecore.yaml ]]
    then
      echo -e "\n### kubeedge edgecore setup:"   
      #$KE_ADM join --help
      #1st keadm join may fail: a second run is then successful
      echo -e "\n### ls /etc/kubeedge (before keadm join #1):"   
      ls -l /etc/kubeedge || true
      echo -e "\n### ls done"   
      (sudo $KE_ADM join \
                --cloudcore-ipport="$KE_CLOUD_IP:$KE_CLOUD_PORT"  \
                --edgenode-name="$KE_EDGE_NODE" \
                --token="$KE_SECURITY_TOKEN") || true
      echo -e "\n### ls /etc/kubeedge (after keadm join #1):" 
      ls -l /etc/kubeedge || true 
      echo -e "\n### ls done"            
      sudo $KE_ADM join \
                --cloudcore-ipport="$KE_CLOUD_IP:$KE_CLOUD_PORT"  \
                --edgenode-name="$KE_EDGE_NODE" \
                --token="$KE_SECURITY_TOKEN"
      echo -e "\n### ls /etc/kubeedge (after keadm join #2):"
      ls -l /etc/kubeedge || true 
      echo -e "\n### ls done"          
    fi
    echo -e "\n### kubeedge edgecore config:"      
    cat /etc/kubeedge/config/edgecore.yaml
    
    echo -e "\n### check mosquitto broker presence:"      
    sudo netstat -tulpn | grep LISTEN | grep 'mosquitto' | grep '0.0.0.0:1883'
   
    echo -e "\n### kubeedge edgecore log (initial):" 
    journalctl -u edgecore.service > edgecore.log
    cat edgecore.log
    
    echo -e "\n### kubeedge edgecore log (after 120s):" 
    sleep 120s
    journalctl -u edgecore.service > edgecore.log
    cat edgecore.log
    
    
  fi
  
  if [[ "$KE_INSTANCE" == *'cloud'* ]]
  then
  
    echo -e "\n### generating kube config: "
    ls -l "$KUBE_CONFIG"
    microk8s config > "$KUBE_CONFIG"
    sudo bash -c "microk8s config > $KUBE_ROOT_CONFIG"
    echo -e "\n### microk8s kube-config:"
    cat "$KUBE_CONFIG"
  
    echo -e "\n### checking status: "
    microk8s status | grep 'microk8s is running'
  
    ls -l "$KUBE_CONFIG"
    microk8s config > "$KUBE_CONFIG"
    sudo bash -c "microk8s config > $KUBE_ROOT_CONFIG"
    echo -e "\n### microk8s kube-config:"
    cat "$KUBE_CONFIG"
  
    if [[ ! -f /etc/kubeedge/config/cloudcore.yaml ]]
    then
      echo -e "\n### kubeedge cloudcore setup:"
      #$KE_ADM init --help
      #sudo $KE_ADM gettoken
      #sudo keadm init --advertise-address=$(hostname -I | awk '{print $1}') --kube-config $HOME/.kube/config
      
      ls -al /usr/local
      ls -al /usr/local/bin
      #1st keadm init may fail: a second run is then successful
      (sudo $KE_ADM init \
                --advertise-address="$KE_INTERNAL_IP"  \
                --kube-config "$KUBE_CONFIG") || 
      (sudo $KE_ADM init \
                --advertise-address="$KE_INTERNAL_IP"  \
                --kube-config "$KUBE_CONFIG")
    fi
    echo -e "$KE_CLOUD_IP_TAG $KE_INTERNAL_IP"
    
    echo -e "\n### get security token:"
    #some wait is needed before token is available
    sleep 20s
    KE_SECURITY_TOKEN=$($KE_ADM gettoken --kube-config "$KUBE_CONFIG")
    echo -e "$KE_SECURITY_TOKEN_TAG $KE_SECURITY_TOKEN"
    
    
  
    echo -e "\n### kubeedge cloudcore config:"
    ls -lh /etc/kubeedge/config/cloudcore.yaml
    cat /etc/kubeedge/config/cloudcore.yaml
  
    echo -e "\n### kubeedge cloudcore log:"
    cat /var/log/kubeedge/cloudcore.log     
  
    # the resources below are deployed by keadm init 
    #microk8s kubectl apply -f 'https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/crds/devices/devices_v1alpha2_device.yaml'
    #microk8s kubectl apply -f 'https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/crds/devices/devices_v1alpha2_devicemodel.yaml'
    #microk8s kubectl apply -f 'https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/crds/reliablesyncs/cluster_objectsync_v1alpha1.yaml'
    #microk8s kubectl apply -f 'https://raw.githubusercontent.com/kubeedge/kubeedge/master/build/crds/reliablesyncs/objectsync_v1alpha1.yaml'

    echo -e "\n### list CRDs:"
    microk8s kubectl get crds
    microk8s kubectl get crds | grep 'devices.devices.kubeedge.io' > null
    microk8s kubectl get crds | grep 'devicemodels.devices.kubeedge.io' > null
    microk8s kubectl get crds | grep 'clusterobjectsyncs.reliablesyncs.kubeedge.io' > null
    microk8s kubectl get crds | grep 'objectsyncs.reliablesyncs.kubeedge.io' > null
  
    echo -e "\n### get all --all-namespaces:"
    microk8s kubectl get all --all-namespaces

  fi
  
  if [[ "$KE_TEMP_MAPPER" == 'true' ]]
  then
    
    echo -e "### deploy device manifests: "
    if [[ "$KE_INSTANCE" == *'cloud'* ]]
    then
       echo -e "### apply device yamls: "
       microk8s kubectl apply -f 'https://raw.githubusercontent.com/didier-durand/microk8s-kubeedge/main/ke-cloud/temperature-device-model.yaml'
       microk8s kubectl apply -f 'https://raw.githubusercontent.com/didier-durand/microk8s-kubeedge/main/ke-cloud/temperature-device.yaml'
       #microk8s kubectl delete -f 'https://raw.githubusercontent.com/didier-durand/microk8s-kubeedge/main/ke-edge/temperature-device-edge-deployment.yaml'
       microk8s kubectl apply -f 'https://raw.githubusercontent.com/didier-durand/microk8s-kubeedge/main/ke-edge/temperature-device-edge-deployment.yaml'
       
       echo -e "### get device models: "
       microk8s kubectl get devicemodels
       
       echo -e "### get devices: "
       microk8s kubectl get devices
       #microk8s kubectl get devices | grep 'temperature-mapper'
       
       echo -e "### get cluster object syncs: "
       microk8s kubectl get clusterobjectsyncs
       
       echo -e "### get object syncs: "
       microk8s kubectl get objectsyncs
       
       echo -e "### get pods: "
       microk8s kubectl get pods
    fi
    
  fi
  
  echo -e "$STEP_COMPLETED $STEP on $KE_INSTANCE"
  echo -e "$SCRIPT_COMPLETED on $KE_INSTANCE"
}

exec_main()
{

  STEP=$1
  ITERATION=$2
  KE_INSTANCE=$3
  KE_CLOUD_IP=$4
  KE_SECURITY_TOKEN=$5
  
  echo -e "executing step: $STEP - iteration: $ITERATION - instance: $KE_INSTANCE - ke cloud ip: $KE_CLOUD_IP - ke security token: $KE_SECURITY_TOKEN"
  
  case "$STEP" in
	1)
		exec_step1 "$STEP" "$KE_INSTANCE" "$KE_CLOUD_IP" "$KE_SECURITY_TOKEN"
		;;
	2)
		exec_step2 "$STEP" "$KE_INSTANCE" "$KE_CLOUD_IP" "$KE_SECURITY_TOKEN"
		;;
	*)
	  echo -e "Unknown step: $STEP"
		exit 1
		;;
  esac
  
}

exec_main "$1" "$2" "$3" "$4" "$5"

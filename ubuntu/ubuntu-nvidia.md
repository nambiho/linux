# ai-server and api server

# install
```
$ sudo apt update && sudo apt upgrade -y
$ sudo -i
```

# ssh
### PC
```
> ssh-keygen -t ed25519
> input directory/key-name
> ssh-copy-id -i directory/key-name.pub -p 2222 username@hostname

{ or }

> cat directory/key-name.pub
> copy & paste (server .ssh/authorized_keys)
```

### server
- config ssh ( /etc/ssh/sshd_config)
- change port
- PasswordAuthentication no
- PermitRootLogin no

```
$ sudo ufw allow port/tcp (if not change port, "sudo dfw allow OpenSSH")
$ sudo ufw status
$ sudo systemctl restart ssh
```

# RTX 3080 GPU driver
~~~
$ sudo apt purge -y nvidia*
$ sudo apt purge -y xserver-xorg-video-nouveau
# echo -e "blacklist nouveau\noptions nouveau modeset=0" | sudo tee /etc/modprobe.d/blacklist-nouveau.conf
$ sudo update-initramfs -u
$ sudo reboot
{ reboot }
$ sudo ubuntu-drivers devices
$ sudo apt install -y nvidia-driver-535
$ nvidia-smi
$ sudo reboot
$ nvcc --version
$ sudo apt install -y nvidia-cuda-toolkit
$ nvcc --version
~~~

# docker
~~~
$ sudo usermod -aG docker hosung
$ systemctl status docker
$ distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
$ curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit.gpg
$ curl -fsSL https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list |   sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit.gpg] https://#g' |   sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
$ sudo apt update
$ sudo apt install -y nvidia-container-toolkit
$ sudo nvidia-ctk runtime configure --runtime=docker
$ sudo systemctl restart docker
$ sudo docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi
~~~

# mount hdd
~~~
$ sudo fdisk -l
$ sudo fdisk /dev/sdb
$ sudo lsblk
$ sudo pvcreate /dev/sdb1
$ sudo vgcreate vg_ai /dev/sdb1
$ sudo lvcreate -l 100%FREE -n lv_ai_data vg_ai
$ sudo mkfs.xfs /dev/vg_ai/lv_ai_data
$ sudo mkdir -p /mnt/ai-data
$ mount /dev/vg_ai/lv_ai_data /mnt/ai-data
~~~

# kubernetis
~~~
$ cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
$ cd ~/.kube
$ chown $(id -u):$(id -g) ./config
$ kubectl create namespace accounting-dev
$ kubectl create ns groupware-dev
$ cd /data1
$ mkdir -p ./kube/deploy

{ create yaml }

$ kubectl get pods -n kube-system

~~~

쿠버네티스 설정
개발환경 설정

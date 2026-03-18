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

# kubernetes (k3s)
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

# kubernetes (k8s)
### index
```
1. OS 사전 준비
2. containerd 설치 및 설정
3. Kubernetes 패키지 설치
4. kubeadm init (클러스터 생성)
5. kubectl 설정
6. 네트워크 CNI 설치 (Calico)
7. 단일 노드 설정
8. 정상 동작 확인
```

### 1. OS 사전 준비
##### Swap 비활성화
- 안하면 kubeadm init 실패
```bash
$ swapoff -a
$ sed -i '/swap/d' /etc/fstab
```

##### 커널 네트워크 설정
```bash
$ cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

$ modprobe br_netfilter
```

```bash
$ cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables=1
EOF

$ sysctl --system
```

##### package
- 없으면 오류 날수 있음
```bash
apt update
apt install -y apt-transport-https ca-certificates curl gnupg
```

### containerd 설치와 설정
```bash
$ apt install -y containerd
# 설치하면 config.toml 있지만 무시하고 명령 수행
$ containerd config default | tee /etc/containerd/config.toml
# cgroup 중요
$ sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
$ grep "SystemdCgroup" /etc/containerd/config.toml
$ systemctl restart containerd
$ systemctl enable containerd
```

### kubernetes 설치
```bash
# 있으면 다음으로 명령
$ mkdir -p /etc/apt/keyrings

$ curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

$ echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

$ apt update
$ apt install -y kubelet kubeadm kubectl
$ apt-mark hold kubelet kubeadm kubectl
```
### 클러스터 생성
```bash
$ swapoff -a            # 스왑 메모리 종료
$ systemctl restart containerd # 컨테이너 런타임 재시작 확인
$ kubeadm init --pod-network-cidr=10.244.0.0/16

	kubeadm join ... # 해당 블럭 저장

```

[실행 후 메세지 마지막 부분]
```
...

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

	kubeadm join 192.168.3.194:6443 --token p39y7u.zwa3npy9xtyczc7i \
        --discovery-token-ca-cert-hash sha256:95dadafe1dd1cf64f6dfeee0d899721e8570491262a80aefca8b51e2fb4c8a10
```

### 클러스터 설정 (kubectl 권한 부여)
```bash
$ mkdir -p /home/gpuuser/.kube
$ sudo cp -i /etc/kubernetes/admin.conf /home/gpuuser/.kube/config
$ sudo chown gpuuser:gpuuser /home/gpuuser/.kube/config
```

### 네트워크 CNI 설치 (Calico)
```bash
# cni 확인
# 서비스 확인 kube-flannel이나 calico-node
# Flannel (가장 쉽고 가벼움)
# Calico (보안 및 고성능)
$ kubectl get pods -n kube-system
$ kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
```



# 개발환경 설정
### ml110 -> gpu server : ssh key copy
~~~bash
$ sudo -u jenkins ssh-keygen -t ed25519 -f /var/lib/jenkins/.ssh/id_ed25519_jenkins_ml110
$ sudo -u jenkins ssh-copy-id -p 30032 -i /var/lib/jenkins/.ssh/id_ed25519_jenkins_ml110.pub hosung@192.168.3.194
~~~

# Ollama
```bash
$ curl -fsSL https://ollama.com/install.sh | sh
$ ollama --version
$ systemctl status ollama
$ systemctl start ollama # 실행이 아니라면
$ systemctl enable ollama
$ ss -lntp | grep 11434 || true
$ curl -s http://127.0.0.1:11434 || true
$ ufw allow 11434/tcp

# gpu 상태 확인
$ nvidia-smi -l 1 # <- 너무 깜박 거림
$ watch -n 1 nvidia-smi # <- 상태 확인으로는 이 명령이 더 좋음


# 환경설정
$ systemctl edit ollama

	[Service]
	Environment="OLLAMA_MODELS=/ai/ollama"
	Environment="OLLAMA_HOST=0.0.0.0"

$ systemctl daemon-reload
$ systemctl restart ollama

# 기존 모델 옮기기
$ rsync -aH --info=progress2 ~/.ollama/ /data/ollama/models/
$ systemctl restart ollama
$ ollama list

# systemctl 실행 일때 모델 다운로드 경로 권한 확인
# 디렉토리가 ollama:ollama 가 되어 있어야함
# 서비스 실행한 유저 확인
$ ps -o user,pid,cmd -C ollama 2>/dev/null || true
$ systemctl show -p User ollama 2>/dev/null || true

# 모델 다운로드
$ ollama pull llama3.1:8b
$ ollama list

# 명령 실행후 nvidia-smi 콘솔 확인하면 모델 적재 확인
$ ollama run llama3.1:8b "hi"

# curl test
$ curl http://127.0.0.1:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "prompt": "GPU VRAM 테스트. 1문장으로 인사해줘.",
    "stream": false
  }'

$ curl http://127.0.0.1:11434/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [
      { "role": "user", "content": "자기소개를 한 문장으로 해줘." }
    ],
    "stream": false
  }'

```

# vLLM
### 1. Python 설치
- Ubuntu 패키지 관리자가 최신 버전을 찾을 수 있도록 `deadsnakes` PPA를 추가
```bash
# PPA 추가를 위한 도구 설치
$ sudo apt update
$ sudo apt install software-properties-common -y

# Python 최신 버전 저장소 추가
$ sudo add-apt-repository ppa:deadsnakes/ppa -y
$ sudo apt update

# Python 3.12 및 가상환경(venv) 모듈 설치
$ sudo apt install python3.12 python3.12-venv python3.12-dev -y
```

### 2. pip 설치
```bash
# 시스템 전체 pip 설치
$ sudo apt install python3-pip -y

# 설치 확인
$ python3.12 --version
$ pip3 --version
```

### 3. 가상환경
```bash
$ cd /ai/vllm

# Python 3.12 버전을 명시하여 가상환경 생성
$ python3.12 -m venv .venv

# 가상환경 활성화
$ source .venv/bin/activate

# (가상환경 내부) pip 자체 업데이트
$ pip install --upgrade pip
```

### 4. vLLM 설치
- 가상환경이 활성화된 상태(`(.venv)` 표시 확인)에서 설치
- 항상 가상환경에서 실행

```bash
$ pip install --upgrade pip
$ pip install vllm
```

### 5. 모델 다운로드
```bash
$ vi ~/.profile

	export HF_HOME='/ai/vllm/cache'
	export OLLAMA_MODELS='/ai/ollama'

$ cd /ai/vllm
$ . ./.venv/bin/activate
$ pip install huggingface_cli
$ huggingface-cli download Qwen/Qwen2.5-7B-Instruct-AWQ --local-dir /ai/vllm/models/Qwen/Qwen2.5-7B-Instruct-AWQ --local-dir-use-symlinks False
$ huggingface-cli download TheBloke/Mistral-7B-Instruct-v0.2-GPTQ --local-dir /ai/vllm/models/TheBloke/Mistral-7B-Instruct-v0.2-GPTQ  --local-dir-use-symlinks False
```

### 6. 실행
```bash
$ python3 -m vllm.entrypoints.openai.api_server \
    --model Qwen/Qwen2.5-7B-Instruct-AWQ \
    --quantization awq \
    --gpu-memory-utilization 0.8 \
    --max-model-len 4096 \
    --port 8000

# Qwem
$ python -m vllm.entrypoints.openai.api_server --model Qwen/Qwen2.5-7B-Instruct-AWQ --quantization awq --gpu-memory-utilization 0.7 --max-model-len 2048 --port 8001

# 오류가 나면 양자화 옵션을 빼고 시도. : --quantization gptq-marlin
$ python -m vllm.entrypoints.openai.api_server --model TheBloke/Mistral-7B-Instruct-v0.2-GPTQ --quantization gptq-marlin --gpu-memory-utilization 0.7 --max-model-len 2048 --port 8001
```

##### 3080 10G options
1. `--quantization awq`: 양자화, 4-bit 압축된 `AWQ` 모델
2. `--gpu-memory-utilization 0.8`: 기본값은 0.9(90%), 메모리 80% 정도
3. `--max-model-len 4096`: 한 번에 처리할 문맥 길이를 제한 메모리 보완

### 7. 테스트
- 확인용 터미널
```bash
$ docker container ls
$ docker logs -f --tail=200 8290d7d0a1c3 # <- CONTAINER ID
$ watch -n 1 nvidia-smi
```

- curl test
```bash
$ curl -v \
-X POST \
-H "Content-Type: application/json" \
-d '{"message":"hi"}' \
"http://localhost:8000/api/v1/chat"
```

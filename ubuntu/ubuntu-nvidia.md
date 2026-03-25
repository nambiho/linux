# **ai-server and api server**

# 1. install
```
$ sudo apt update && sudo apt upgrade -y
$ sudo -i
```

# 2. ssh
### 1) PC
```
> ssh-keygen -t ed25519
> input directory/key-name
> ssh-copy-id -i directory/key-name.pub -p 2222 username@hostname

{ or }

> cat directory/key-name.pub
> copy & paste (server .ssh/authorized_keys)
```

### 2) server
- config ssh ( /etc/ssh/sshd_config)
- change port
- PasswordAuthentication no
- PermitRootLogin no

```
$ sudo ufw allow port/tcp (if not change port, "sudo dfw allow OpenSSH")
$ sudo ufw status
$ sudo systemctl restart ssh
```

# 3. RTX 3080 GPU driver
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

# 4. docker
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

# 5. mount hdd
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

# 6. kubernetes (k3s)
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

# 7. kubernetes (k8s)
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
9. GPU 연결
10. helm 설치
11. Metrics 서버
12. longhorn 설치
13. nginx ingress controller 설치
14. k9s
15. gpu test
16. vLLM 배포
```

### 1) OS 사전 준비
##### Swap 비활성화
- 안하면 kubeadm init 실패
```bash
$ swapoff -a
$ sed -i '/swap/d' /etc/fstab
$ vi /etc/fstab
# vi 에서 nvme0n1p2의 내용을 주석 처리 
# 만약 없다면 아래도 처리
$ systemctl mask dev-nvme0n1p2.swap
# free -h 했을때 swap부분에 0 0 0 이 나와야 함
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

### 2) containerd 설치와 설정
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

### 3) kubernetes 설치
```bash
# 있으면 다음으로 명령
$ mkdir -p /etc/apt/keyrings

$ curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

$ echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' > /etc/apt/sources.list.d/kubernetes.list

$ apt update
$ apt install -y kubelet kubeadm kubectl
$ apt-mark hold kubelet kubeadm kubectl
```
### 4) 클러스터 생성
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

### 5) 클러스터 설정 (kubectl 권한 부여)
```bash
$ mkdir -p /home/gpuuser/.kube
$ sudo cp -i /etc/kubernetes/admin.conf /home/gpuuser/.kube/config
$ sudo chown gpuuser:gpuuser /home/gpuuser/.kube/config
```

### 6) 네트워크 CNI 설치 (Calico)
[참고](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)
```bash
# cni 확인
# 서비스 확인 kube-flannel이나 calico-node
# Flannel (가장 쉽고 가벼움)
# Calico (보안 및 고성능)
# 고전적
$ kubectl get pods -n kube-system
# 최신
$ kubectl get namespaces # 여기에 네임스페이스가 있으면
$ kubectl get pods -n tigera-operator

# 공홈에서
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml

# 고전적인 설치 방법
$ kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# 확인
$ watch kubectl get tigerastatus
```
[메세지]
```bash
$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/tigera-operator.yaml
namespace/tigera-operator created
serviceaccount/tigera-operator created
clusterrole.rbac.authorization.k8s.io/tigera-operator-secrets created
clusterrole.rbac.authorization.k8s.io/tigera-operator created
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator created
rolebinding.rbac.authorization.k8s.io/tigera-operator-secrets created
deployment.apps/tigera-operator created

$ kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created
goldmane.operator.tigera.io/default created
whisker.operator.tigera.io/default created
```

### 7) 단일 서버인 경우
- 단일 서버이기 때문에 마스터 서버에서 pod 실행 허용하기
```bash
$ kubectl taint nodes --all node-role.kubernetes.io/control-plane-

# 아래는 참고만
# 특정 마스터 노드(master-01)에서만 제한 해제 - 
$ kubectl taint nodes master-01 node-role.kubernetes.io/control-plane-
# GPU 노드에 'gpu=true'라는 전용 Taint 추가 (NoSchedule: 허용된 Pod 외엔 금지)
$ kubectl taint nodes gpu-node-01 gpu=true:NoSchedule
```

### 8) 정상 동작 확인
```bash
$ kubectl get nodes
$ kubectl get pods -A
```

### 9) GPU 연결
[참고 1](https://github.com/NVIDIA/k8s-device-plugin?tab=readme-ov-file)
[참고 2](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuring-cri-o)
```bash
# 도커용 nvidia-container-runtime 툴킷을 containerd 로 이전
# nvidia-ctk 를 이용
$ nvidia-ctk runtime configure --runtime=containerd
$ systemctl restart containerd
$ kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

# create, apply 처음 실행은 상관없음
# 두번째 재발행 부터는 create 는 오류남
# $ kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

$ kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.17.1/deployments/static/nvidia-device-plugin.yml

$ kubectl describe node | grep -i gpu
# 명령을 했을때 처음에 아무것도 안나와서 [Troubleshooting -1] 처리함
# 처리 완료 후 다음 메세지 나옴
  nvidia.com/gpu:     1
  nvidia.com/gpu:     1
  nvidia.com/gpu     0           0
```

[Troubleshooting - 1]
```bash
# calico-system이 ns 없음
# 원인 : kubeadm init --pod-network-cidr=10.244.0.0/16 할때 
# 10.244.0.0은 Flannel ip 대역이고, 
# calico 는 192.168.0.0 을 기본 대역으로 사용함
# 그래서 네트워크가 실행이 안됨
###
$ kubectl cluster-info dump | grep -i podcidr
                "podCIDR": "10.244.0.0/24",
                "podCIDRs": [
I0318 10:53:16.860724       1 range_allocator.go:380] "Set node PodCIDR" node="ai-server-1" podCIDRs=["10.244.0.0/24"]
# 수정

$ kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml
$ curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/custom-resources.yaml
$ vi custom-resources.yaml

	cidr: 192.168.0.0/16 #<- 이 부분을
	cidr: 10.244.0.0/16 #<- 이렇게 변경 하고 저장

$ kubectl apply -f custom-resources.yaml
$ watch -n 1 kubectl get pods -A
# calico-system 이 모두 running 이 되는 것 확인
```

### 10) helm 설치
[참고](https://helm.sh/ko/docs/v3/intro/install)
```bash
$ curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
$ helm version
$ helm list
```

### 11) Metrics 서버
```bash
$ kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
$ kubectl edit deployment metrics-server -n kube-system

	# 아래 확인 하여 있으면 넣지 않고, 없으면 넣고 저장
	- --kubelet-insecure-tls #인증 무시
	- --kubelet-preferred-address-types=InternalIP

$ kubectl delete pod -n kube-system -l k8s-app=metrics-server
# 10초 후에
$ kubectl top nodes
$ kubectl logs -n kube-system deployment/metrics-server
```

### 12) longhorn 설치
- 데이터 공유라고 하는데 왜 쓰는지 아직 모름
- 기본 디렉토리가 /var/lib/longhorn 이고 서버마다 같은 디렉토리여야함
- A서버에서 /ai, B서버에서 /var/lib 이면 안된다고 함
- 다른 서버에서 지정된 모델을 사용 하기 위해서 넣는다고 하는데
- 이해가 부족해서 삭제 함

##### 설치
```bash
$ helm repo add longhorn https://charts.longhorn.io
$ helm repo update
$ kubectl create namespace longhorn-system
$ helm install longhorn longhorn/longhorn --namespace longhorn-system
$ kubectl get pods -n longhorn-system
```
##### StorageClass 설정
```bash
$ kubectl get storageclass
$ kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

##### 삭제
```bash
kubectl delete -f https://raw.githubusercontent.com/longhorn/longhorn/v1.6.0/deploy/longhorn.yaml
helm uninstall longhorn -n longhorn-system
kubectl delete namespace longhorn-system
kubectl get all -n longhorn-system # 더 있는지 확인
sudo rm -rf /var/lib/longhorn
kubectl get storageclass
kubectl delete storageclass longhorn
kubectl delete storageclass longhorn-static
```


### 13) nginx ingress controller 설치
##### URL 설치
```bash
# 보통 테스트용으로 설치하지만 기능은 모두 됨
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml

$ kubectl get pods -n ingress-nginx
$ kubectl get svc -n ingress-nginx
# 다음으로 테스트 ingress yaml 생성하고 테스트 합니다.
```
```yaml
# test-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
spec:
  ingressClassName: nginx
  rules:
  - host: test.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```

```bash
$ kubectl apply -f test-ingress.yaml
```

##### helm 설치
```bash
# 레포지토리 추가 및 업데이트
$ helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
$ helm repo update

# 설치
# 이름은 지정 해야함
# 다음 처럼 명령어에 옵션을 붙일수도 있지만
# 보통 values.yaml 파일을 만들어서 실행 하고 업데이트 한다.
$ helm install my-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \ # AWS 사용 시
  --set controller.config.proxy-body-size="50m" \ # 파일 업로드 용량 제한 해제
  --set controller.config.proxy-read-timeout="300" # AI 추론 대기 시간 연장

# 다음과 같이 values.yaml 을 만들수 있음
# controller:
#   config:
#    # AI 응답 대기 시간 (300초)
#    proxy-read-timeout: "300"
#    # 요청 본문 크기 제한 (50MB)
#    proxy-body-size: "50m"
#  service:
#    annotations:
#      # AWS 환경에서 NLB 사용 시 활성화 (AWS가 아니면 삭제 가능)
#      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```

##### MetalLB 설치
```bash
$ kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/main/config/manifests/metallb-native.yaml

$ ip a # 실제 ip 대역의 ip를 할당 해야하기 때문에
```

```yaml
# metallb-config.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.3.240-192.168.3.250
```

```bash
$ kubectl apply -f ~/kube-config/metallb/metallb-config.yaml
```

```yaml
# values.yaml
# 서비스 타입 (NodePort / LoadBalancer)
# ingress 클래스 이름
# 복제 수 (고가용성)
# CPU / 메모리 제한

# NodePort/LoadBalancer
# LoadBalancer 는
# 클라우드의 로드밸러스를 이용하지 않는다면 MetalLB 같은  지원 서비스 설치 해야함
controller:
  service:
    type: LoadBalancer

  ingressClassResource:
    name: nginx
    enabled: true

  replicaCount: 2

  config:
    proxy-read-timeout: "300"
    proxy-body-size: "50m"

  resources:
    limits:
      cpu: "1"
      memory: "1Gi"
    requests:
      cpu: "500m"
      memory: "512Mi"
```

```bash
# namespace 생성
# 이렇게 따로 만들수도 있고, nginx controller 생성시에 넣을수도 있다.
# nginx controller 생성시에 namespace 생성할때는 업데이트 할때는 빼야함
# -n ingress-nginx --create-namespace \
$ kubectl create namespace ingress-nginx
$ helm install ingress-nginx ingress-nginx/ingress-nginx \
-n ingress-nginx \
-f ~/kube-config/helm/nginx/values.yaml

# 실행 메세지
	NAME: ingress-nginx
	LAST DEPLOYED: Mon Mar 23 13:59:36 2026
	NAMESPACE: ingress-nginx
	STATUS: deployed
	REVISION: 1
	TEST SUITE: None
	NOTES:
	The ingress-nginx controller has been installed.
	It may take a few minutes for the load balancer IP to be available.
	You can watch the status by running 'kubectl get service --namespace default ingress-nginx-controller --output wide --watch'

	An example Ingress that makes use of the controller:
		apiVersion: networking.k8s.io/v1
		kind: Ingress
		metadata:
			name: example
			namespace: foo
		spec:
			ingressClassName: nginx
			rules:
				- host: www.example.com
					http:
						paths:
							- pathType: Prefix
								backend:
									service:
										name: exampleService
										port:
											number: 80
								path: /
			# This section is only required if TLS is to be enabled for the Ingress
			tls:
				- hosts:
					- www.example.com
					secretName: example-tls

	If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

		apiVersion: v1
		kind: Secret
		metadata:
			name: example-tls
			namespace: foo
		data:
			tls.crt: <base64 encoded cert>
			tls.key: <base64 encoded key>
		type: kubernetes.io/tls


# 몇분 후에
$ kubectl get svc -n ingress-nginx
```

[Troubleshooting - nginx controller]
- helm 으로 ingress-nginx 를 설치 할때 namespace를 지정 하지 않아서
- kubectl get svc -n ingress-nginx 가 나오지 않고
- kubectl get svc -n default 에 리스트가 나오고 있음
- nginx 를 삭제 하고 다시 설정 해야함
- 그리고 위 helm 설치 내용에 -n ingress-nginx 를 추가 했음
```bash
$ helm list -A
$ helm uninstall ingress-nginx -n default
$ kubectl delete namespace ingress-nginx
$ helm install ingress-nginx ingress-nginx/ingress-nginx \
-n ingress-nginx \
-f ~/kube-config/helm/nginx/values.yaml
$ kubectl get svc -n ingress-nginx
```

### 14) k9s
- kubernetes 설치 후에 언제든 설치 가능함
```bash
$ curl -sS https://webinstall.dev/k9s | bash
$ . ~/.bashrc
```


### 15) gpu test
```yaml
# gpu-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: gpu-test
spec:
  restartPolicy: Never
  containers:
  - name: cuda
    image: nvidia/cuda:12.2.0-base-ubuntu22.04
    command: ["nvidia-smi"]
    resources:
      limits:
        nvidia.com/gpu: 1
```

```bash
$ kubectl apply -f ~/kube-config/gpu-test/gpu-test.yaml
$ kubectl logs gpu-test
```

### 16) vLLM 배포
[참고 - vllm k8s](https://docs.vllm.ai/en/stable/deployment/k8s/)
[참고 - vllm/vllm-openai](https://hub.docker.com/r/vllm/vllm-openai)
```yaml
# deployment-qwen.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-qwen
	namespace: ai
  labels:
    app: vllm-qwen
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-qwen
  template:
    metadata:
      labels:
        app: vllm-qwen
    spec:
      containers:
        - name: vllm
          image: vllm/vllm-openai:v0.10.2 # 버전을 latest 사용하지 않고 직접 입력
          # command: ["python", "-m", "vllm.entrypoints.openai.api_server"]
          # args:
          #   - "--model"
          #   - "/models/Qwen2.5-7B-Instruct-AWQ"
          #   - "--quantization"
          #   - "awq"
          #   - "--gpu-memory-utilization"
          #   - "0.7"
          #   - "--max-model-len"
          #   - "2048"
          #   - "--port"
          #   - "8001"
          args:
            - "--model"
            - "/models/Qwen2.5-7B-Instruct-AWQ"
            - "--quantization"
            - "awq"
            - "--gpu-memory-utilization"
            - "0.7"
            - "--max-model-len"
            - "2048"
            - "--port"
            - "8001"
          ports:
            - containerPort: 8001
              name: http
          resources:
            limits:
              nvidia.com/gpu: 1
          volumeMounts:
            - name: model
              mountPath: /models
      volumes:
        - name: model
          hostPath:
            path: /ai/models/vllm/models/Qwen/Qwen2.5-7B-Instruct-AWQ
            type: Directory
```

```yaml
# service-qwen.yaml
apiVersion: v1
kind: Service
metadata:
  name: vllm-qwen
	namespace: ai
  labels:
    app: vllm-qwen
spec:
  selector:
    app: vllm-qwen
  ports:
    - name: http
      port: 8001
      targetPort: 8001
  type: ClusterIP
```

```yaml
# ingress-serve.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vllm-serve
	namespace: ai
	annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  labels:
    app: vllm-serve
spec:
  ingressClassName: nginx
  # tls:
  #   - hosts:
  #       - qwen.example.com
  #     secretName: qwen-tls
  rules:
    #- host: vllm-qwen.local
    -  http:
        paths:
          - path: /qwen(/|$)(.*)
            pathType: ImplementationSpecific # Prefix 를 사용하지 않음
            backend:
              service:
                name: vllm-qwen
                port:
                  number: 8001
          - path: /llama(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: vllm-llama
                port:
                  number: 8001
					- path: /mistral(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: vllm-mistral
                port:
                  number: 8001
```
```bash
$ kubectl apply -f ~/kube-config/vllm/deployment-qwen.yaml
$ curl http://192.168.3.241/qwen/v1/chat/completions \
-X POST \
-H "Content-Type: application/json" \
-d '{
  "model": "/models",
  "messages": [
    { "role": "user", "content": "자기소개를 한 문장으로 해줘." }
  ],
  "stream": false
}'
```

[troubleshoot - 경로문제]
- deployment-qwen.yaml
- args의 -model내용에 /models/Qwen...을 사용했었는데
- /models로 변경 하고 해결

[troubleshoot - vllm 버전 문제]
- 컨테이너가 더 새로운 CUDA 런타임을 사용하려고 함
- 호스트의 NVIDIA 드라이버가 그 CUDA를 직접 지원하지 못함
- 그래서 CUDA가 forward compatibility 방식으로 우회하려고 하는데
- 현재 GPU/하드웨어가 그 방식을 지원하지 않음
- 아래 명령을 이용해서 cuda 버전이 맞는 것 이미지 버전을 찾아야 한다.
- kubectl get pod -n ai 해서 pod 이름을 확인
- kubectl -n ai exec -it  vllm-qwen-5d89c96c9d-knxv7 -- python3 -c "import torch; print(f'torch : {torch.__version__}'); print(f'cuda : {torch.version.cuda}')"
- 버전을 변경 해 가면서 실행 되는 이미지를 선택
- cuda 버전 12.8 은 v0.10.2


### 17) Ollama 배포
```bash
# vllm 이 모든 VRAM을 차지 하고 있기 때문에 중지 또는 삭제를 해야함
# name은 pod 이름이 아니고 등록할때 yaml에 있는 이름
$ kubectl get deployment -n ai
# 셋중 하나
$ kubectl scale deployment [name] -n ai --replicas=0
$ kubectl delete deployment [name] -n ai
$ kubectl delete -f deployment-qwen.yaml

# 나머지 service, ingress도 삭제 해도 됨
$ kubectl delete service [name] -n ai
$ kubectl delete ingress [name] -n ai
```

```yaml
# deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: ai
  labels:
    app: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
        - name: ollama
          image: ollama/ollama:0.18.2 # 버전을 latest 사용하지 않고 직접 입력
          env:
            - name: OLLAMA_HOST
              value: "0.0.0.0:11434"
          ports:
            - containerPort: 11434
              name: http
          resources:
            limits:
              nvidia.com/gpu: 1
          volumeMounts:
            - name: ollama-data
              mountPath: /root/.ollama/models
      volumes:
        - name: ollama-data
          hostPath:
            path: /ai/models/ollama
            type: Directory
```

```yaml
# service.yaml

apiVersion: v1
kind: Service
metadata:
  name: ollama
  namespace: ai
  labels:
    app: ollama
spec:
  selector:
    app: ollama
  ports:
    - name: http
      port: 11434
      targetPort: 11434
  type: ClusterIP
```

```yaml
# ingress-serve.yaml

apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ollama-serve
  namespace: ai
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
  labels:
    app: ollama-serve
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          - path: /ollama(/|$)(.*)
            pathType: ImplementationSpecific # Prefix 를 사용하지 않음
            backend:
              service:
                name: ollama
                port:
                  number: 11434
```

```bash
$ kubectl apply -f ~/kube-config/ollama/deployment.yaml
$ kubectl apply -f ~/kube-config/ollama/service.yaml
$ kubectl apply -f ~/kube-config/ollama/ingress-serve.yaml

$ curl http://192.168.3.241/ollama/v1/chat/completions \
-X POST \
-H "Content-Type: application/json" \
-d '{
  "model": "qwen2.5:7b-instruct",
  "messages": [
    { "role": "user", "content": "자기소개를 한 문장으로 해줘." }
  ],
  "stream": false
}'

# 모델 다운로드
$ kubectl -n ai exec -it <ollama-pod> -- ollama pull llama3

# 테스트
$ curl http://ollama.local/api/tags
```


# 7. add worker of kubernetes (k8s)
- 다른 서버에서 쿠버네티스 워커를 추가 할때
### 1) 마스터
```bash
$ kubeadm token create --print-join-command

	# 처음 kubeadm init 했던것 처럼 kubeadm jon ... 복사
	kubeadm join 123.456... --token ... --discovery-token-ca-cert-hash ...
```

### 2) 워커
```bash
$ kubeadm join 123.456... (복사한 내용)
```

### 3) 확인
- 마스터
```bash
kubectl get nodes
```

### 4) 마스터가 워커 사용하기
```bash
# node 라벨 붙이기
$ kubectl label nodes ai-server-02 gpu-type=rtx4090
# yaml에 gpu-type=rtx4090 에는 이런 일을 하라고 지시
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-server
  labels:
    app: vllm
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm
  template:
    metadata:
      labels:
        app: vllm
    spec:
      # --- 여기가 핵심: 특정 라벨이 있는 노드로만 배포 ---
      nodeSelector:
        gpu-type: rtx4090
      # ---------------------------------------------
      containers:
      - name: vllm-container
        image: vllm/vllm-openai:latest
        resources:
          limits:
            nvidia.com/gpu: 1 # GPU 1개를 점유하겠다는 설정
        ports:
        - containerPort: 8000
        env:
        - name: MODEL_NAME
          value: "facebook/opt-125m" # 예시 모델명
        volumeMounts:
        - name: model-volume
          mountPath: /root/.cache/huggingface
      volumes:
      - name: model-volume
        hostPath:
          path: /ai/models # 실제 AI 서버의 모델 경로
```


# 8. 개발환경 설정
### ml110 -> gpu server : ssh key copy
~~~bash
$ sudo -u jenkins ssh-keygen -t ed25519 -f /var/lib/jenkins/.ssh/id_ed25519_jenkins_ml110
$ sudo -u jenkins ssh-copy-id -p 30032 -i /var/lib/jenkins/.ssh/id_ed25519_jenkins_ml110.pub hosung@192.168.3.194
~~~

# 9. Ollama
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
	Environment="OLLAMA_MODELS=/ai/models/ollama"
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

# 10. vLLM
### 1) Python 설치
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

### 2) pip 설치
```bash
# 시스템 전체 pip 설치
$ sudo apt install python3-pip -y

# 설치 확인
$ python3.12 --version
$ pip3 --version
```

### 3) 가상환경
```bash
$ cd /ai/vllm

# Python 3.12 버전을 명시하여 가상환경 생성
$ python3.12 -m venv .venv

# 가상환경 활성화
$ source .venv/bin/activate

# (가상환경 내부) pip 자체 업데이트
$ pip install --upgrade pip
```

### 4) vLLM 설치
- 가상환경이 활성화된 상태(`(.venv)` 표시 확인)에서 설치
- 항상 가상환경에서 실행

```bash
$ pip install --upgrade pip
$ pip install vllm
```

### 5) 모델 다운로드
```bash
$ vi ~/.profile

	export HF_HOME='/ai/models/vllm/cache'
	export OLLAMA_MODELS='/ai/models/ollama'

$ cd /ai/vllm
$ . ./.venv/bin/activate
$ pip install huggingface_cli
$ huggingface-cli download Qwen/Qwen2.5-7B-Instruct-AWQ --local-dir /ai/models/vllm/models/Qwen/Qwen2.5-7B-Instruct-AWQ --local-dir-use-symlinks False
$ huggingface-cli download TheBloke/Mistral-7B-Instruct-v0.2-GPTQ --local-dir /ai/models/vllm/models/TheBloke/Mistral-7B-Instruct-v0.2-GPTQ  --local-dir-use-symlinks False
```

### 6) 실행
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

### 7) 테스트
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

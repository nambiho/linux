# 인스톨 가이드 7 — ML110(Rocky Linux) 추가 워커 · Kubernetes(kubeadm) 편입

이 문서는 **Rocky Linux(예: ML110 앱 서버)** 를 **이미 구축된 kubeadm Kubernetes 클러스터**에 **워커 노드로 추가**하는 절차입니다.  
**컨트롤 플레인(마스터)은 AI 서버(Ubuntu)에 이미 있다**는 전제입니다.

---

## 작업 환경

| 항목 | 값 |
|------|-----|
| 작업 사용자 | `kube` (sudo 권한 필요) |
| 워커 노드 OS | Rocky Linux (ML110) |
| 마스터 노드 OS | Ubuntu (AI 서버) |

> 이 문서의 모든 명령은 `kube` 사용자로 실행합니다.  
> `sudo`가 붙은 명령은 root 권한이 필요하므로, `kube` 사용자가 `sudo` 그룹에 속해 있어야 합니다.  
> `sudo` 권한이 없다면 먼저 root에서 `usermod -aG wheel kube`를 실행합니다.
> calico를 이용하기 위해서 179 port를 모두 열어야 합니다.

---

## 전제 확인 (필수)

| 항목 | 내용 |
|------|------|
| 마스터 | kubeadm으로 구성됨, `kubectl get nodes` 정상 |
| CNI | Calico 등 이미 설치됨 |
| 버전 | **워커의 kubelet/kubeadm 버전 = 마스터와 동일 minor** 필수 |
| 네트워크 | 워커에서 마스터 **6443** TCP 도달 가능 |

---

## 전체 진행 흐름

```
1. [마스터] Kubernetes 버전 확인 + join 명령 생성
2. [워커]  k3s 제거 (있을 경우)
3. [워커]  잔여 디렉터리 정리
4. [워커]  Rocky Linux OS 준비 (swap, 커널 모듈, sysctl)
5. [워커]  containerd 설치 및 설정
6. [워커]  kubeadm / kubelet / kubectl 설치
7. [워커]  SELinux · 방화벽
8. [워커]  kubeadm join
9. [마스터] 노드 확인 · 라벨 · taint · Ingress Controller
10. [마스터/워커] tomboy 앱 배포
```

---

## 1단계 — 마스터에서 버전 확인 + join 명령 생성

> **실행 위치: 마스터(AI 서버, Ubuntu)**  
> **실행 사용자: kube**

### 1-1. Kubernetes 버전 확인

워커에 설치할 패키지 버전을 맞추기 위해, 마스터의 버전을 먼저 확인합니다.

```bash
kubectl version -o yaml | grep gitVersion
```

출력 예시:

```
  gitVersion: v1.29.3
```

위 결과에서 **minor 버전(예: `v1.29`)** 을 기록해 둡니다. 이후 6단계에서 사용합니다.

### 1-2. join 명령 생성

```bash
kubeadm token create --print-join-command
```

출력 예시를 **그대로 복사**해 메모장 등에 저장합니다.

```bash
kubeadm join 192.168.3.194:6443 --token e9zjw5.2knahimjqrw03sui --discovery-token-ca-cert-hash sha256:95dadafe1dd1cf64f6dfeee0d899721e8570491262a80aefca8b51e2fb4c8a10
```

> 토큰은 **24시간 후 만료**됩니다. 만료되면 위 명령을 다시 실행하여 재발급합니다.

---

## 2단계 — ML110(Rocky)에서 k3s 제거

> **실행 위치: 워커(ML110, Rocky Linux)**  
> **실행 사용자: kube (sudo 필요)**

k3s가 **설치되어 있지 않으면** 이 단계를 건너뜁니다.

먼저 k3s 설치 여부를 확인합니다:

```bash
which k3s 2>/dev/null && echo "k3s 설치됨" || echo "k3s 없음 → 3단계로 이동"
```

k3s가 설치되어 있다면, **역할에 맞는 스크립트만** 실행합니다:

```bash
# k3s 서버(마스터)였던 경우
sudo /usr/local/bin/k3s-uninstall.sh

# k3s 에이전트(워커)였던 경우
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

제거 확인:

```bash
ps -ef | grep -E 'k3s' | grep -v grep
```

아무것도 출력되지 않으면 정상입니다.

---

## 3단계 — 잔여 파일 정리 (충돌 방지)

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

이전 k3s나 kubelet 잔여 파일이 남아 있으면 새 설치와 충돌합니다.

```bash
sudo rm -rf /etc/rancher
sudo rm -rf /var/lib/rancher
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/cni/net.d
```

> **주의:** 다른 용도로 쓰는 데이터가 위 경로에 있으면 백업 후 진행합니다.

---

## 4단계 — Rocky Linux OS 준비

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

### 4-1. 시스템 업데이트

```bash
sudo dnf update -y
```

### 4-2. swap 비활성화

kubeadm은 기본적으로 swap이 꺼져 있어야 합니다.

```bash
# 현재 세션에서 즉시 끄기
sudo swapoff -a

# 재부팅 후에도 유지 — fstab에서 swap 라인을 주석 처리
sudo sed -i.bak 's/^[^#].*swap.*/#&/' /etc/fstab
```

적용 확인:

```bash
free -h
```

`Swap:` 행이 모두 `0`이면 정상입니다.

### 4-3. 커널 모듈 로드 (재부팅 후에도 유지)

```bash
cat <<'EOF' | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
```

로드 확인:

```bash
lsmod | grep -E 'overlay|br_netfilter'
```

두 모듈이 모두 표시되면 정상입니다.

### 4-4. sysctl 파라미터 설정 (영구 적용)

```bash
cat <<'EOF' | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

적용 확인:

```bash
sysctl net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward
```

모두 `= 1`이면 정상입니다.

---

## 5단계 — containerd 설치 및 설정

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

### 5-1. Docker 공식 저장소 추가

Rocky Linux 기본 저장소에는 containerd 패키지가 없으므로, Docker 공식 저장소를 추가합니다.

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
```

### 5-2. containerd 설치

```bash
sudo dnf install -y containerd.io
```

### 5-3. 기본 설정 파일 생성

```bash
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

### 5-4. SystemdCgroup 활성화

Kubernetes는 systemd cgroup 드라이버를 사용합니다. 기본값이 `false`이므로 `true`로 변경해야 합니다.

```bash
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

변경 확인:

```bash
grep 'SystemdCgroup' /etc/containerd/config.toml
```

`SystemdCgroup = true`가 출력되면 정상입니다.

### 5-5. sandbox_image 확인 (선택)

마스터에서 사용 중인 pause 이미지 버전과 맞추는 것이 권장됩니다.

**마스터에서** pause 이미지 확인:

```bash
# [마스터에서 실행]
kubeadm config images list 2>/dev/null | grep pause
```

출력 예시: `registry.k8s.io/pause:3.9`

워커의 config.toml에서 해당 버전으로 맞춥니다:

```bash
# [워커에서 실행] — 버전 번호를 마스터와 동일하게 수정
sudo sed -i 's|sandbox_image = "registry.k8s.io/pause:.*"|sandbox_image = "registry.k8s.io/pause:3.9"|' /etc/containerd/config.toml
```

### 5-6. containerd 기동

```bash
sudo systemctl restart containerd
sudo systemctl enable containerd
```

상태 확인:

```bash
sudo systemctl status containerd
```

`active (running)` 상태이면 정상입니다.

---

## 6단계 — Kubernetes 패키지 저장소 및 설치

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

> **중요:** 1단계에서 확인한 마스터의 Kubernetes minor 버전과 동일하게 맞춥니다.  
> 아래 예시는 `v1.29` 기준입니다. 다른 버전이면 URL의 `v1.29`를 해당 버전으로 바꿉니다.

### 6-1. 저장소 등록

```bash
cat <<'EOF' | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF
```

### 6-2. 패키지 설치

```bash
sudo dnf install -y kubelet kubeadm kubectl
```

### 6-3. kubelet 활성화

```bash
sudo systemctl enable --now kubelet
```

> kubelet은 join 전에는 정상 기동되지 않고 재시작을 반복하는 것이 **정상 동작**입니다.  
> kubeadm join 후에 안정됩니다.

### 6-4. 버전 잠금 (업그레이드 방지)

의도치 않은 자동 업그레이드를 방지합니다.

```bash
sudo dnf install -y 'dnf-command(versionlock)'
sudo dnf versionlock kubelet kubeadm kubectl
```

---

## 7단계 — SELinux · 방화벽

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

### 7-1. SELinux

현재 상태를 확인합니다:

```bash
getenforce
```

`Enforcing` 상태에서 join이 실패할 경우, permissive로 전환합니다:

```bash
# 일시적 전환 (재부팅 시 복원)
sudo setenforce 0

# 영구 전환이 필요한 경우
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
```

### 7-2. firewalld

firewalld가 실행 중인지 확인합니다:

```bash
sudo systemctl status firewalld
```

실행 중이라면, 워커 노드에 필요한 포트를 개방합니다:

```bash
# kubelet API
sudo firewall-cmd --permanent --add-port=10250/tcp

# NodePort 서비스 범위
sudo firewall-cmd --permanent --add-port=30000-32767/tcp

# CNI(Calico VXLAN) — Calico 사용 시
sudo firewall-cmd --permanent --add-port=4789/udp

sudo firewall-cmd --reload
```

> 사내 폐쇄망이라면 `sudo systemctl disable --now firewalld`로 비활성화하는 것도 방법입니다.

---

## 8단계 — 클러스터에 조인

> **실행 위치: 워커(ML110)**  
> **실행 사용자: kube (sudo 필요)**

1단계에서 저장해 둔 join 명령을 **그대로** 실행합니다:

```bash
sudo kubeadm join <API서버IP>:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

# 실제 적용 코드
sudo kubeadm join 192.168.3.194:6443 --token e9zjw5.2knahimjqrw03sui --discovery-token-ca-cert-hash sha256:95dadafe1dd1cf64f6dfeee0d899721e8570491262a80aefca8b51e2fb4c8a10
```

> `<API서버IP>`, `<token>`, `<hash>` 부분을 1단계에서 복사한 실제 값으로 바꿉니다.

성공 시 아래와 유사한 메시지가 출력됩니다:

```
This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.
```

### join 실패 시 — 토큰 만료

1단계에서 24시간이 지났다면 토큰이 만료되었을 수 있습니다.

```bash
# [마스터에서 실행] 새 토큰 발급
kubeadm token create --print-join-command
```

새로 출력된 명령으로 다시 join합니다.

### join 실패 시 — 이전 join 흔적 제거 후 재시도

```bash
# [워커에서 실행]
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
```

이후 `kubeadm join` 명령을 다시 실행합니다.

---

## 9단계 — 마스터에서 노드 확인

> **실행 위치: 마스터(AI 서버, Ubuntu)**  
> **실행 사용자: kube**

```bash
kubectl get nodes -o wide
```

ML110 노드가 목록에 나타나고, STATUS가 `Ready`가 될 때까지 **1~2분** 대기합니다.

`NotReady` 상태가 5분 이상 지속되면 워커에서 kubelet 로그를 확인합니다:

```bash
# [워커에서 실행]
sudo journalctl -u kubelet -f --no-pager
```

### 노드 라벨 지정

역할을 구분하기 위해 **마스터에서** 실행합니다:

```bash
# AI 서버(마스터)에 라벨
kubectl label node <마스터노드이름> role=ai --overwrite
kubectl label node ai-server-1 node-role.kubernetes.io/ai=

# 앱 서버(워커)에 라벨
kubectl label node <ML110-노드이름> role=app --overwrite
kubectl label node superman node-role.kubernetes.io/app=

# 확인
kubectl get nodes --show-labels
```

---

### AI 노드 taint 설정 (역할 분리 핵심)

AI 서버(마스터)에 일반 앱 파드가 올라오지 못하게 taint를 겁니다.  
**마스터에서** 실행합니다:

```bash
kubectl taint nodes <마스터노드이름> workload=ai:NoSchedule
```

확인:

```bash
kubectl describe node <마스터노드이름> | grep Taints
# 결과 예시: Taints: workload=ai:NoSchedule
```

> Calico, kube-proxy 같은 시스템 DaemonSet은 기본 toleration이 있어 영향 없습니다.

---

### AI Deployment — toleration + nodeSelector 예시

AI 관련 파드(vLLM 등)는 taint를 통과하도록 toleration을 넣고, nodeSelector로 AI 노드를 지정합니다:

```yaml
spec:
  tolerations:
  - key: "workload"
    operator: "Equal"
    value: "ai"
    effect: "NoSchedule"
  nodeSelector:
    role: ai
```

---

### 앱 Deployment — nodeSelector만 (toleration 없음)

앱 파드는 toleration이 없으므로 마스터(AI 노드)에 스케줄되지 않고, nodeSelector로 워커에만 배치됩니다:

```yaml
spec:
  nodeSelector:
    role: app
```

---

### Ingress Controller를 워커(앱 서버)에 고정

Ingress는 앱 트래픽을 받으므로 워커에 두는 것이 자연스럽습니다.  
Helm values 파일(`loadbalance.yaml` 등)에 추가합니다:

```yaml
controller:
  nodeSelector:
    role: app
```

적용:

```bash
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx \
  -f ~/kube-config/nginx-ingress/ingress_type/loadbalance.yaml
```

확인:

```bash
kubectl get pods -n ingress-nginx -o wide
# NODE 열이 워커(ML110)로 표시되면 정상
```

---

## 10단계 — tomboy 앱 배포

> **실행 위치: 마스터 / 워커** — 각 명령에 `[마스터]` `[워커]` 표기  
> **실행 사용자: kube**
>
> 매니페스트 위치: `tomboy/auth-server/deployment/k8s/`

### 10-1. Namespace 생성 [마스터]

```bash
kubectl create namespace tomboy
```

### 10-2. 컨테이너 이미지 빌드 및 배포

#### 이미지 배포 방식 — 레지스트리 유무에 따라 다름

| | 레지스트리 없음 (현재) | 레지스트리 있음 |
|--|----------------------|----------------|
| 빌드 후 처리 | `docker save` → `scp` → `ctr import` | `docker push` |
| 노드 추가 시 | 노드마다 수동으로 이미지 전송 필요 | 쿠버네티스가 각 노드에서 자동 pull |
| deployment.yaml | `image: auth-server:latest` | `image: 레지스트리IP/tomboy/auth-server:latest` |
| imagePullPolicy | `IfNotPresent` | `Always` 권장 |
| 적합한 환경 | 노드 1~2대 소규모, 폐쇄망 | 노드 다수, CI/CD 자동화 |

#### 레지스트리 종류

| 종류 | 특징 | 적합한 환경 |
|------|------|------------|
| **Docker Registry** | 설정 단순, 기능 최소 | 소규모, 빠른 구축 |
| **Harbor** | UI·권한관리·취약점 스캔 제공 | 팀 운영, 보안 요구 환경 |
| **Docker Hub** | 공개 이미지 전용 (ollama, vllm 등) | 공개 이미지 사용 시 |

> **현재 환경 판단**: 워커 1대, 폐쇄망 → 레지스트리 없이 `ctr import` 방식이 적합.  
> 노드가 늘어날 경우 Docker Registry 또는 Harbor 도입을 검토.

---

#### 현재 방식 — 레지스트리 없음 (ctr import)

`deployment.yaml`의 `imagePullPolicy: IfNotPresent` 설정에 의해, **파드가 뜨는 노드(워커)의 containerd에 이미지가 있어야** 합니다.

> Jenkins가 워커에서 실행 중이라면 `scp` 전송 없이 바로 `ctr import` 가능.

**[워커/Jenkins] 빌드 및 import:**

```bash
# auth-server 프로젝트 루트에서
./gradlew bootWar
docker build -f deployment/Dockerfile -t auth-server:latest .

# containerd k8s.io 네임스페이스에 import
docker save auth-server:latest -o /tmp/auth-server.tar
sudo ctr -n k8s.io images import /tmp/auth-server.tar
rm -f /tmp/auth-server.tar
```

import 확인:

```bash
sudo ctr -n k8s.io images list | grep auth-server
# docker.io/library/auth-server:latest 가 표시되면 정상
```

Jenkins가 마스터에서 실행 중이라면 **워커로 전송 후 import**:

```bash
docker save auth-server:latest -o auth-server.tar
scp auth-server.tar kube@<워커IP>:~/
# [워커에서]
sudo ctr -n k8s.io images import ~/auth-server.tar
```

---

#### 레지스트리 있을 때 — Docker Registry (참고)

레지스트리가 구축된 경우 `ctr import` 단계가 사라지고 `docker push`로 대체됩니다.

```bash
# 빌드 시 레지스트리 주소를 태그에 포함
docker build -f deployment/Dockerfile -t <레지스트리IP>:5000/tomboy/auth-server:latest .

# 레지스트리에 push
docker push <레지스트리IP>:5000/tomboy/auth-server:latest
```

`deployment.yaml` 이미지 경로 변경:

```yaml
image: <레지스트리IP>:5000/tomboy/auth-server:latest
imagePullPolicy: Always
```

이후 `kubectl apply`만 하면 쿠버네티스가 각 노드에서 자동으로 pull합니다.

### 10-3. ConfigMap · Secret 적용 [마스터]

> `secret.yaml`의 `DB_PASSWORD: "changeme"`를 **실제 비밀번호로 변경** 후 적용합니다.  
> `configmap.yaml`의 `DB_HOST`, `REDIS_HOST` 등 IP가 현재 환경과 맞는지 확인합니다.

```bash
kubectl apply -f deployment/k8s/configmap.yaml
kubectl apply -f deployment/k8s/secret.yaml # 권장 하지 않음. 아래 secret 적용 참조
```

> secret 적용
```bash
# secret은 파일 배포보다 직접 명령을 사용 하는것을 권장한다.
# 기존 secret 삭제 후 재생성
kubectl delete secret auth-server-secret -n tomboy
kubectl create secret generic auth-server-secret \
    --namespace=tomboy \
    --from-literal=DB_PASSWORD=실제DB비밀번호 \
    --from-literal=REDIS_PASSWORD=실제Redis비밀번호

# 또는 덮어쓰기 옵션으로:
kubectl create secret generic auth-server-secret \
    --namespace=tomboy \
    --from-literal=DB_PASSWORD=실제DB비밀번호 \
    --from-literal=REDIS_PASSWORD=실제Redis비밀번호 \
    --dry-run=client -o yaml | kubectl apply -f -
```


### 10-4. Deployment 적용 [마스터]

기존 `deployment.yaml`에 **nodeSelector를 추가**하여 워커에만 배치되도록 합니다.  
`spec.template.spec` 아래에 다음을 추가합니다:

```yaml
      nodeSelector:
        role: app
```

추가 후 전체 구조 예시:

```yaml
spec:
  template:
    spec:
      nodeSelector:
        role: app
      containers:
        - name: auth-server
          image: auth-server:latest
          ...
```

적용:

```bash
kubectl apply -f deployment/k8s/deployment.yaml
```

### 10-5. Service 적용 [마스터]

```bash
kubectl apply -f deployment/k8s/service.yaml
```

### 10-6. k9s 설치 (공용 설치 — 모든 사용자 사용 가능)

> **실행 위치: 마스터 또는 워커 (설치할 노드에서 각각 실행)**  
> root로 설치한 경우 kube 계정에서 실행이 안 될 수 있습니다.  
> **공용 경로(`/usr/local/bin`)에 설치하면 모든 사용자가 사용 가능**합니다.

#### 기존 설치 위치 확인

먼저 이미 설치되어 있는지 확인합니다:
```bash
# ubuntu 에서 설치 했던 내용은 계정 디렉토리에 설치 됨
$ curl -sS https://webinstall.dev/k9s | bash
$ . ~/.bashrc
```


```bash
# 현재 사용자 기준
which k9s || echo "k9s not in PATH"

# root 기준
sudo which k9s
```

- `which k9s` 출력이 `/usr/local/bin/k9s`이면 → **공용 설치 완료**, 아래 재설치 불필요
- `/root/...` 같은 경로면 → root 홈에만 있는 것이므로 공용 재설치 필요
- 아무 출력이 없으면 → 미설치 상태, 아래 절차 진행

#### 최신 버전 공용 설치

```bash
# 1) 최신 버전 번호 확인 (예: v0.32.7)
curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
  | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/'

# 2) /tmp에 다운로드 및 압축 해제 (버전은 위 결과로 교체)
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest \
  | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')

cd /tmp
curl -L -o k9s.tar.gz \
  "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"

tar -xzf k9s.tar.gz k9s

# 3) 공용 경로에 설치 (모든 사용자 실행 가능)
sudo install -m 0755 k9s /usr/local/bin/k9s

# 4) 임시 파일 정리
rm -f /tmp/k9s /tmp/k9s.tar.gz
```

#### 폐쇄망 환경 (인터넷 미연결)

인터넷이 되는 PC에서 미리 다운로드 후 서버로 전송합니다:

```bash
# [인터넷 PC] GitHub Releases 페이지에서 수동 다운로드
# https://github.com/derailed/k9s/releases → k9s_Linux_amd64.tar.gz

# [인터넷 PC → 서버 전송]
scp k9s_Linux_amd64.tar.gz kube@<서버IP>:~/

# [서버에서] 압축 해제 및 공용 설치
cd ~
tar -xzf k9s_Linux_amd64.tar.gz k9s
sudo install -m 0755 k9s /usr/local/bin/k9s
rm -f ~/k9s ~/k9s_Linux_amd64.tar.gz
```

#### 설치 확인

```bash
which k9s
# /usr/local/bin/k9s 가 출력되면 정상

k9s version
```

> 설치 후 **로그아웃/재로그인 없이** 바로 실행됩니다.  
> kube, root 등 **모든 계정에서 사용 가능**합니다.

---

### 10-7. 확인 — k9s

```bash
k9s -n tomboy
```

또는 CLI로 확인:

```bash
kubectl get pods -n tomboy -o wide
# NODE 열이 워커(ML110)로 표시되고 STATUS가 Running이면 정상
```

### 10-7. (선택) Ingress 적용 [마스터]

> Ingress Controller(nginx-ingress)가 **이미 설치되어 있어야** 합니다 (위 "Ingress Controller를 워커에 고정" 참고).

기존 `ingress.yaml`은 k3s Traefik 기반이므로, kubeadm nginx-ingress 환경에 맞게 수정이 필요합니다:

| 항목 | 변경 전 (k3s/Traefik) | 변경 후 (kubeadm/nginx) |
|------|----------------------|------------------------|
| `ingressClassName` | `traefik` | `nginx` |
| annotations | `traefik.ingress.kubernetes.io/*` | 제거 |

수정 후 적용:

```bash
kubectl apply -f deployment/k8s/ingress.yaml
```

---

### taint 제거 (단일 노드로 복귀 시)

워커를 분리하고 마스터 혼자 쓸 때는 taint를 제거해야 파드가 마스터에 스케줄됩니다:

```bash
kubectl taint nodes <마스터노드이름> workload=ai:NoSchedule-
```

> 끝에 `-`를 붙이면 해당 taint가 삭제됩니다.

---

## 문제 발생 시 점검 가이드

| 증상 | 점검 사항 | 실행 위치 |
|------|-----------|-----------|
| join 실패 (connection refused) | 마스터 API 주소 확인, 방화벽 6443 개방 여부 | 워커 |
| join 실패 (certificate) | NTP 시간 동기화 확인: `timedatectl status` | 양쪽 |
| NotReady 장시간 | CNI 마스터 설치 상태, kubelet 로그 확인 | 마스터/워커 |
| CRI 오류 | containerd 기동 확인, `SystemdCgroup = true` 확인 | 워커 |
| crictl 없음 | `sudo dnf install -y cri-tools` | 워커 |
| 이미 join된 상태 | `sudo kubeadm reset -f` 후 재시도 | 워커 |
| `kubelet.conf already exists` / `Port 10250 in use` | 이전 join 잔여. `sudo kubeadm reset -f && sudo rm -rf /etc/kubernetes /var/lib/kubelet /etc/cni/net.d` 후 재시도 | 워커 |
| `tc not found` WARNING | 동작에 영향 없음. 해소하려면 `sudo dnf install -y iproute-tc` | 워커 |
| `hostname could not be reached` WARNING | 동작에 영향 없음. 해소하려면 `/etc/hosts`에 `127.0.0.1 <hostname>` 추가 | 워커 |

---

### Troubleshooting — resolv.conf 오류 (Rocky Linux 빈발)

**증상:** join 성공 후 파드가 `ContainerCreating`에서 멈추고, `kubectl describe pod`에 다음 이벤트 출력:

```
Failed to create pod sandbox: open /run/systemd/resolve/resolv.conf: no such file or directory
```

**원인:** 마스터(Ubuntu)는 `systemd-resolved`를 쓰면서 `/run/systemd/resolve/resolv.conf`가 있지만, Rocky Linux는 `systemd-resolved`를 기본으로 쓰지 않아 해당 파일이 없음. kubelet이 DNS 설정을 그 경로에서 읽으려다 실패.

**해결 (워커에서 실행):**

```bash
# 1) 즉시 해결 — 심볼릭 링크 생성
sudo mkdir -p /run/systemd/resolve
sudo ln -sf /etc/resolv.conf /run/systemd/resolve/resolv.conf

# 2) 근본 해결 — kubelet 설정의 resolvConf 경로 변경
sudo sed -i 's|/run/systemd/resolve/resolv.conf|/etc/resolv.conf|' /var/lib/kubelet/config.yaml

# 3) kubelet 재시작
sudo systemctl restart kubelet
```

> `/run/` 디렉터리는 재부팅 시 초기화되므로, 1)만 하면 재부팅 후 재발. **1)과 2) 둘 다** 적용을 권장.

**확인 (마스터에서):**

```bash
kubectl get pods -n kube-system -o wide | grep <워커노드이름>
kubectl get nodes
```

파드가 `Running`, 노드가 `Ready`로 전환되면 해결.

---

### Troubleshooting — Calico BGP 미성립 + Pod egress 불가 (Typha 포트 차단)

**증상:**

- `kubectl -n calico-system get pod -l k8s-app=calico-node` 에서 각 노드의 calico-node 가 장시간 `0/1 Running` 상태.
- Readiness 이벤트: `calico/node is not ready: BIRD is not ready: BGP not established with <peer-ip>`.
- Pod 에서 외부 HTTPS 접속 실패 (`curl -I https://1.1.1.1` → `Couldn't connect to server`). 호스트에서는 정상.
- Grafana 가 `grafana.com` 에서 대시보드 import 시 `Bad gateway` (→ Grafana Pod egress 차단의 파생 증상).

**최종 확인된 원인:**

Ubuntu 쪽 노드(예: ai-server-1, 마스터)의 **UFW 에 Calico Typha 포트 `5473/tcp` 가 누락**. BGP 포트 `179/tcp` 만 열려 있음. 그 결과 Rocky 쪽 노드(예: superman)의 calico-node 가 Typha 에 i/o timeout 으로 붙지 못해 confd 가 BGP 설정을 렌더링하지 못하고, `/etc/calico/confd/config/bird.cfg` 가 생성되지 않아 BIRD 가 기동하지 못함. 양쪽 BGP mesh 불성립.

핵심 로그 패턴 (Rocky 워커 calico-node 에서 반복):

```
[WARNING] felix/sync_client.go: Failed to connect to typha endpoint 192.168.3.194:5473. ... i/o timeout
bird: Unable to open configuration file /etc/calico/confd/config/bird.cfg: No such file or directory
```

#### 1) 순차적 확인 명령 (마스터에서 실행)

```bash
# 1-1. 노드와 calico-node 상태
kubectl get nodes -o wide
kubectl -n calico-system get pod -l k8s-app=calico-node -o wide

# 1-2. 각 노드의 Calico IPv4 어노테이션 (예상 값: 노드 INTERNAL-IP/마스크)
kubectl get node <ubuntu-node>  -o jsonpath='{.metadata.annotations.projectcalico\.org/IPv4Address}{"\n"}'
kubectl get node <rocky-node>   -o jsonpath='{.metadata.annotations.projectcalico\.org/IPv4Address}{"\n"}'

# 1-3. BIRD peering 상태 (모든 calico-node 파드 대상)
for p in $(kubectl -n calico-system get pod -l k8s-app=calico-node -o name); do
  echo "===== $p ====="
  kubectl -n calico-system exec -c calico-node ${p##*/} -- birdcl show protocols | grep -E 'Mesh|name'
done
# 기대값: Mesh_<peer-ip> 가 state=Established 여야 정상.
# 비정상 예:
#   - Active / Connect + "Connection refused"  → 반대편 bird 미기동
#   - Connect + "No route to host" / timeout   → 네트워크/방화벽 차단
#   - "Unable to connect to server control socket (/var/run/calico/bird.ctl)" → 해당 파드에서 bird 자체 미기동

# 1-4. Installation 자동감지 설정 (spec 과 computed 일치 여부)
kubectl get installation default -o jsonpath='V4_SPEC={.spec.calicoNetwork.nodeAddressAutodetectionV4}{"\n"}'
kubectl get installation default -o jsonpath='V6_SPEC={.spec.calicoNetwork.nodeAddressAutodetectionV6}{"\n"}'
kubectl get installation default -o jsonpath='V4_COMPUTED={.status.computed.calicoNetwork.nodeAddressAutodetectionV4}{"\n"}'
kubectl get installation default -o jsonpath='V6_COMPUTED={.status.computed.calicoNetwork.nodeAddressAutodetectionV6}{"\n"}'

# 1-5. 워커 calico-node 실제 환경 변수
POD=$(kubectl -n calico-system get pod -l k8s-app=calico-node --field-selector spec.nodeName=<rocky-node> -o name | head -1 | cut -d/ -f2)
kubectl -n calico-system exec -c calico-node $POD -- \
  sh -c 'env | grep -E "IP_AUTODETECTION_METHOD|^IP=|CALICO_NETWORKING_BACKEND"'

# 1-6. 워커 calico-node 로그 (핵심 실패 시그널 확인)
kubectl -n calico-system logs $POD -c calico-node --tail=300 \
  | grep -E "typha endpoint|bird.cfg|Unable to open configuration"

# 1-7. tigera-operator 반복 에러
kubectl -n tigera-operator logs deploy/tigera-operator --tail=300 \
  | grep -i "autodetection\|Invalid\|Degraded" | tail -5
```

#### 2) 워커(Rocky) 호스트에서 확인 — 로컬 bird 충돌 여부

```bash
# 호스트에서 179 를 다른 프로세스가 쥐고 있는지
sudo ss -lntp | grep ':179'

# systemd bird 유무 (있으면 호스트 bird 와 파드 bird 가 충돌)
systemctl list-unit-files | grep -i bird
systemctl status bird 2>/dev/null | head -5
```

> 위 3개 명령이 모두 "무출력" 이면 호스트 측 충돌은 아님. 문제는 네트워크/방화벽 쪽.

#### 3) 워커(Rocky) 에서 마스터(Ubuntu) 로의 Calico 통신 포트 연결 테스트

```bash
# 마스터 IP 가 192.168.3.194 라고 가정
nc -vz 192.168.3.194 5473   # Typha (반드시 succeeded)
nc -vz 192.168.3.194 179    # BGP
```

- `5473` 에서 **timeout / refused** 가 나오면 이 Troubleshooting 의 전형적 시나리오에 해당.

#### 4) 해결 — 마스터(Ubuntu, UFW) 에 누락 포트 개방

**노드-간 트래픽은 `192.168.3.0/24` 대역이라고 가정.** 환경에 맞게 수정.

```bash
# [마스터(Ubuntu) 에서 실행]
# 4-1. 현재 상태
sudo ufw status verbose

# 4-2. Calico 필수 포트 전부 허용 (대역 제한)
sudo ufw allow from 192.168.3.0/24 to any port 179  proto tcp   # BGP
sudo ufw allow from 192.168.3.0/24 to any port 5473 proto tcp   # Typha (핵심)
sudo ufw allow from 192.168.3.0/24 to any port 4789 proto udp   # VXLAN
sudo ufw allow from 192.168.3.0/24 to any port 10250 proto tcp  # kubelet

# 4-3. 포워딩 허용 (Pod egress 를 위해 필요)
sudo ufw default allow routed

# 4-4. 재로드 및 확인
sudo ufw reload
sudo ufw status verbose
```

#### 5) 해결 — 워커(Rocky, firewalld) 쪽도 동일 포트 개방

```bash
# [워커(Rocky) 에서 실행]
# 5-1. 상태
sudo firewall-cmd --state
sudo firewall-cmd --get-default-zone
sudo firewall-cmd --list-all

# 5-2. Calico 포트 영구 허용
sudo firewall-cmd --permanent --add-port=179/tcp
sudo firewall-cmd --permanent --add-port=5473/tcp
sudo firewall-cmd --permanent --add-port=4789/udp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports

# 5-3. (선택) 노드 대역을 신뢰 존으로 등록하여 잡음 제거
sudo firewall-cmd --permanent --zone=trusted --add-source=192.168.3.0/24
# Pod CIDR 도 파악되면 함께 추가 (예: 10.244.0.0/16)
sudo firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16
sudo firewall-cmd --reload
```

#### 6) calico-node 재순환 및 검증

```bash
# [마스터에서]
kubectl -n calico-system rollout restart ds/calico-node
kubectl -n calico-system get pod -l k8s-app=calico-node -o wide -w
# READY 가 양쪽 모두 1/1 이면 성공

# BGP Mesh Established 확인
for p in $(kubectl -n calico-system get pod -l k8s-app=calico-node -o name); do
  echo "===== $p ====="
  kubectl -n calico-system exec -c calico-node ${p##*/} -- birdcl show protocols | grep -E 'Mesh|Established'
done

# bird.cfg 가 워커 calico-node 안에 생성 되었는지
POD=$(kubectl -n calico-system get pod -l k8s-app=calico-node --field-selector spec.nodeName=<rocky-node> -o name | head -1 | cut -d/ -f2)
kubectl -n calico-system exec -c calico-node $POD -- \
  sh -c 'ls -l /etc/calico/confd/config/bird.cfg && head -30 /etc/calico/confd/config/bird.cfg'

# Pod egress 최종 확인
kubectl run netchk --rm -it --image=curlimages/curl --restart=Never -- \
  sh -c 'curl -sI https://1.1.1.1 | head -1; curl -sI https://grafana.com | head -1'

# Installation 상태
kubectl get installation default -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
# 기대값: Ready=True, Degraded=False, Progressing=False
```

#### 7) (선택) NIC 2개가 동일 서브넷일 때의 자동감지 고정

워커 노드에 NIC 이 2개(eno1, eno2) 이고 둘 다 동일 `/24` 서브넷 인 경우, Calico 가 `first-found` 로 의도치 않은 NIC 을 선택할 수 있음. 사용할 NIC 을 명시 고정:

```bash
# [마스터에서]
kubectl patch installation default --type=merge -p '{
  "spec": {
    "calicoNetwork": {
      "nodeAddressAutodetectionV4": {"interface": "eno1"}
    }
  }
}'

# 반영 확인 (몇 초 대기)
kubectl get installation default -o jsonpath='V4_COMPUTED={.status.computed.calicoNetwork.nodeAddressAutodetectionV4}{"\n"}'
# 기대값: V4_COMPUTED={"interface":"eno1"}

# 옛 어노테이션 캐시가 남아 있으면 제거 후 재시작
kubectl annotate node <rocky-node> projectcalico.org/IPv4Address-
kubectl annotate node <rocky-node> projectcalico.org/IPv4VXLANTunnelAddr- 2>/dev/null || true
kubectl -n calico-system rollout restart ds/calico-node
```

> `nodeAddressAutodetectionV4` 는 `firstFound / kubernetes / interface / skipInterface / canReach / cidrs` 중 **정확히 하나만** 설정 가능. 2개 이상 존재하면 tigera-operator 가 `no more than one node address autodetection method can be specified per-family` 로 reconcile 을 거부한다. V6 도 동일 규칙.

#### 8) 요약 체크리스트

| 항목 | 확인 명령 | 기대값 |
|------|-----------|--------|
| Ubuntu 쪽 UFW | `sudo ufw status verbose` | 179/5473/4789/10250 모두 ALLOW, `routed` 는 allow |
| Rocky 쪽 firewalld | `sudo firewall-cmd --list-ports` | 179/5473/4789/10250 포함 |
| 노드 간 Typha 연결 | 워커에서 `nc -vz <master-ip> 5473` | `succeeded` |
| calico-node READY | `kubectl -n calico-system get pod -l k8s-app=calico-node` | 모든 파드 `1/1` |
| BGP Mesh | `birdcl show protocols \| grep Mesh` | `state=Established` |
| bird.cfg | 워커 파드에서 `ls /etc/calico/confd/config/bird.cfg` | 파일 존재 |
| Pod egress | 테스트 파드에서 `curl -sI https://1.1.1.1` | `HTTP/...` 응답 |

---

### Troubleshooting — Grafana 에 특정 노드의 메트릭이 보이지 않음 (Prometheus 스크랩 방화벽 차단)

**증상:**

- Grafana "Node Exporter Full" 류 대시보드에 **노드 중 일부만 표시**됨 (예: superman 만 보이고 ai-server-1 은 안 보임).
- `kubectl get pods -A -o wide | grep node-exporter` 상으로는 DaemonSet 이 `2/2 READY`, 모든 노드에 파드가 정상 기동.
- Prometheus 내부 쿼리:
    ```promql
    up{job="node-exporter"}
    ```
    결과에서 한 instance 는 `value=1`, 다른 instance 는 `value=0`.

**최종 확인된 원인:**

monitoring 네임스페이스의 Prometheus 파드는 `nodeSelector: role=app` 로 **superman 에만** 스케줄됨. Prometheus 가 노드 메트릭을 수집하려면 **ai-server-1:9100(node-exporter)** 으로 TCP 접근이 가능해야 하는데, ai-server-1 의 UFW 에 `9100/tcp` 가 열려 있지 않아 스크랩이 drop 되고 `up=0` 이 됨.

같은 이유로 **마스터 노드(ai-server-1)** 의 아래 컴포넌트 메트릭도 누락 가능:

- `kube-controller-manager` → `10257/tcp`
- `kube-scheduler` → `10259/tcp`
- `kube-proxy` (metrics) → `10249/tcp`
- `etcd` → `2381/tcp` (bind 설정 시)

#### 1) 진단

```bash
# 1-1. DaemonSet/파드 배치는 정상인지 먼저 확인 (toleration, 노드 수)
kubectl get ds -A | grep -Ei 'node-exporter'
kubectl get pods -A -o wide | grep -Ei 'node-exporter'

# 1-2. Prometheus 가 실제로 보고 있는 스크랩 상태
PPOD=$(kubectl -n monitoring get pod -l app.kubernetes.io/name=prometheus -o name | head -1 | cut -d/ -f2)
kubectl -n monitoring exec -c prometheus $PPOD -- \
  wget -qO- 'http://localhost:9090/api/v1/query?query=up{job="node-exporter"}' \
  | python3 -m json.tool

# 1-3. 실패 원인(에러 문자열) 직접 확인
kubectl -n monitoring exec -c prometheus $PPOD -- \
  wget -qO- 'http://localhost:9090/api/v1/targets?state=any' \
  | grep -o '"lastError":"[^"]*"' | sort -u
# 기대 패턴: "connection timed out" / "i/o timeout" → 방화벽 drop
#           "connection refused" → 해당 포트 listener 없음
```

#### 2) 연결성 테스트 (Prometheus 가 있는 노드에서 스크랩 대상 노드로)

```bash
# Prometheus 가 superman 에 있고, ai-server-1 을 스크랩하지 못하는 경우:
# superman 에서
nc -vz 192.168.3.194 9100    # node-exporter
nc -vz 192.168.3.194 10257   # kube-controller-manager
nc -vz 192.168.3.194 10259   # kube-scheduler
nc -vz 192.168.3.194 10249   # kube-proxy metrics
```

`timed out` → UFW drop 확정.

#### 3) 해결 — ai-server-1(Ubuntu, UFW) 에 모니터링 포트 개방

```bash
# [ai-server-1 에서 실행]
sudo ufw allow from 192.168.3.0/24 to any port 9100  proto tcp   # node-exporter
sudo ufw allow from 192.168.3.0/24 to any port 10257 proto tcp   # kube-controller-manager
sudo ufw allow from 192.168.3.0/24 to any port 10259 proto tcp   # kube-scheduler
sudo ufw allow from 192.168.3.0/24 to any port 10249 proto tcp   # kube-proxy metrics
sudo ufw reload
sudo ufw status verbose
```

> `etcd` metrics 를 Prometheus 에 수집하려면 `2381/tcp` 도 추가. 단, etcd 는 기본 bind 가 localhost 라 별도의 `--listen-metrics-urls=http://0.0.0.0:2381` 설정 필요.

#### 4) 해결 — superman(Rocky, firewalld) 도 동일 포트 개방 (반대 방향 수집을 대비)

```bash
# [superman 에서 실행]
sudo firewall-cmd --permanent --add-port=9100/tcp
sudo firewall-cmd --permanent --add-port=10257/tcp
sudo firewall-cmd --permanent --add-port=10259/tcp
sudo firewall-cmd --permanent --add-port=10249/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

#### 5) 검증

- 적용 후 1~2분 내 `up{job="node-exporter"}` 가 모든 instance 에서 `1` 로 전환.
- Grafana 의 `instance` / `nodename` 변수 드롭다운에 누락 노드가 나타남.
- "kube-controller-manager" / "kube-scheduler" 관련 대시보드도 함께 정상화.

#### 6) 참고 — 같은 패턴 (다른 증상이 같은 원인)

| 증상 | 실제 원인 |
|------|-----------|
| Grafana 에 특정 노드 메트릭 누락 | `9100` 차단 |
| "kube-controller-manager is down" 알림 | `10257` 차단 |
| "kube-scheduler is down" 알림 | `10259` 차단 |
| Loki/Alloy 에 특정 노드 로그 누락 | Alloy DaemonSet taint 미통과 또는 수집 포트(`4317/4318`) 차단 |

---

### 참고 — kubeadm + Calico + kube-prometheus-stack 환경의 열어야 할 포트 모음

아래는 ai-server-1 / superman 양쪽에서 `192.168.3.0/24` 내부로 허용해야 할 최소 포트 목록. 외부(LAN 외부) 에 노출할 필요는 없으므로 반드시 **소스 대역 제한** 으로 허용 권장.

| 포트 | Proto | 방향 | 용도 / 사용처 | 비고 |
|---|---|---|---|---|
| `6443` | TCP | 워커 → 마스터 | kube-apiserver | kubeadm join, kubectl |
| `10250` | TCP | 전 방향 | kubelet API | 노드 간 `kubectl exec/logs`, Prometheus 의 kubelet/cAdvisor 메트릭 스크랩 |
| `10249` | TCP | Prometheus → 전 노드 | kube-proxy metrics | kps 의 `kube-proxy` ServiceMonitor 대상 |
| `10257` | TCP | Prometheus → 마스터 | kube-controller-manager metrics | 마스터 컴포넌트 전용 |
| `10259` | TCP | Prometheus → 마스터 | kube-scheduler metrics | 마스터 컴포넌트 전용 |
| `2381` | TCP | Prometheus → 마스터 | etcd metrics | etcd `--listen-metrics-urls` 설정 시 |
| `9100` | TCP | Prometheus → 전 노드 | node-exporter | kps DaemonSet, hostNetwork |
| `179` | TCP | 전 방향 (노드 간) | Calico BGP (BIRD) | calico-node mesh |
| `5473` | TCP | 전 방향 (노드 간) | Calico Typha | `calico-node` → `typha` 동기화. 누락 시 confd 가 bird.cfg 못 만듦 |
| `4789` | UDP | 전 방향 (노드 간) | Calico VXLAN | `encapsulation: VXLAN` 일 때 Pod 간 오버레이 트래픽 |
| `30000-32767` | TCP | 외부 → 노드 | Kubernetes NodePort 범위 | NodePort 서비스 사용 시 |
| `4317` / `4318` | TCP | Alloy/Otel → 수집기 | OTLP gRPC / HTTP | 관측 스택에서 사용 시 |

UFW 일괄 적용 예시 (ai-server-1):
```bash
# Kubernetes 코어
sudo ufw allow from 192.168.3.0/24 to any port 6443  proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 10250 proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 10249 proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 10257 proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 10259 proto tcp

# Calico
sudo ufw allow from 192.168.3.0/24 to any port 179  proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 5473 proto tcp
sudo ufw allow from 192.168.3.0/24 to any port 4789 proto udp

# Observability
sudo ufw allow from 192.168.3.0/24 to any port 9100 proto tcp

# Pod egress / 포워딩
sudo ufw default allow routed

sudo ufw reload
sudo ufw status verbose
```

firewalld 일괄 적용 예시 (superman):
```bash
for p in 6443 10250 10249 10257 10259 179 5473 9100; do
  sudo firewall-cmd --permanent --add-port=${p}/tcp
done
sudo firewall-cmd --permanent --add-port=4789/udp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

---

### Troubleshooting — Java 앱 OTLP 송신 시 Alloy 4318 timeout (OTLP receiver 포트 미노출)

#### 1) 현상

- Spring Boot + OTel Java Agent (`-javaagent:/.../opentelemetry-javaagent.jar`) 가 적용된 Pod 가 기동 시 아래 로그를 반복.
- `OTEL_EXPORTER_OTLP_ENDPOINT=http://alloy.monitoring.svc:4318` 로 설정.

```
[otel.javaagent ...] ERROR HttpExporter - Failed to export metrics ... Socket closed
[otel.javaagent ...] ERROR HttpExporter - Failed to export logs ... timeout
java.io.InterruptedIOException: timeout
```

- 임시 Pod 에서 직접 curl 시도해도 동일하게 timeout.

```
* connect to 10.x.x.x port 4318 from 10.244.x.x port xxxxx failed: Operation timed out
curl: (28) Failed to connect ... port 4318 ... Could not connect to server
```

#### 2) 원인

- Alloy Service 가 `12345/TCP` (alloy 자체 metrics) 만 노출하고 있음.
  ```
  alloy   ClusterIP   10.x.x.x   <none>   12345/TCP
  ```
- Alloy `configMap.content` 에는 `otelcol.receiver.otlp` 가 정의되어 4317/4318 listen 하도록 되어 있지만, **Service 객체에 4317/4318 이 노출되어 있지 않아** 클러스터 내부 트래픽이 도달 불가.
- 즉, **Pod 내부에서는 listen 하지만 Service 가 차단**하는 형태.

#### 3) 해결 — Alloy Helm values 에 포트 노출 + receiver 의 `output` 누락 보완

(1) `alloy.extraPorts` 와 `service.extraPorts` 양쪽 모두 등록 (chart 버전에 따라 둘 다 필요).

```yaml
alloy:
  extraPorts:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
      protocol: TCP
    - name: otlp-http
      port: 4318
      targetPort: 4318
      protocol: TCP
  configMap:
    create: true
    content: |
      otelcol.receiver.otlp "default" {
        grpc { endpoint = "0.0.0.0:4317" }
        http { endpoint = "0.0.0.0:4318" }
        output {
          traces  = [otelcol.exporter.otlp.tempo.input]
          metrics = [otelcol.exporter.prometheus.prom.input]
          // logs 는 stdout JSON → loki.source.kubernetes 로 따로 수집하므로 핸들러 불필요
        }
      }
      // ... 기존 exporter 설정

service:
  enabled: true
  type: ClusterIP
  extraPorts:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
      protocol: TCP
    - name: otlp-http
      port: 4318
      targetPort: 4318
      protocol: TCP
```

(2) Helm 적용 후 PORT 확인:

```bash
helm upgrade alloy grafana/alloy -n monitoring -f values.yaml
kubectl get svc -n monitoring alloy
# PORT(S) 에 12345, 4317, 4318 모두 보이면 정상
```

(3) 앱 측 — OTLP receiver 의 `output { logs = ... }` 를 정의하지 않을 거라면, Java Agent 의 logs 송신을 끄지 않으면 매 5초마다 404 가 발생함. stdout JSON 로그를 `loki.source.kubernetes` 로 이미 수집하는 구성이라면 OTLP logs 는 비활성화 권장.

```yaml
env:
  - name: OTEL_LOGS_EXPORTER
    value: "none"
```

#### 4) 같은 패턴 (다른 증상이 같은 원인)

| 증상 | 실제 원인 |
|------|-----------|
| `HttpExporter - Failed to export ... timeout` | Alloy Service 에 4317/4318 미노출 |
| `HTTP status code 404. Unable to parse response body` | Alloy `otelcol.receiver.otlp` 의 `output` 에 logs/metrics/traces 중 하나 누락 |
| 모든 노드 OTLP timeout | DNS 가 아니라 Service 포트 누락 (DNS 는 정상이라도 미노출 포트는 timeout 으로 보임) |

---

### Troubleshooting — Spring Boot Pod 가 0/1 무한 재시작 (Probe 시간 부족)

#### 1) 현상

- `kubectl get pod` 에 READY 가 계속 `0/1` 이고 `RESTARTS` 가 증가.
- `kubectl describe pod` Events:
  ```
  Warning  Unhealthy  ... Readiness probe failed: ... 8100: connect: connection refused
  Warning  BackOff    ... Back-off restarting failed container
  ```
- `kubectl logs` 로 보면 어플리케이션 자체는 정상 기동 중. 마지막에 `Started ... Application in 78.782 seconds` 등이 찍힘.

#### 2) 원인

- OTel Java Agent + Spring Security + JPA + Flyway + Redis 등의 초기화로 **기동에 60~120초** 소요.
- 기존 probe 설정:
  ```yaml
  livenessProbe.initialDelaySeconds: 60
  readinessProbe.initialDelaySeconds: 30
  ```
- 60 초 시점에 liveness 가 health endpoint 에 접근하지만 아직 기동 중이라 실패 → kubelet 이 컨테이너를 재시작 → 다시 기동 시도 → 다시 60 초에 실패. **무한 루프.**

#### 3) 해결 — `startupProbe` 도입

`startupProbe` 가 통과될 때까지 `livenessProbe` / `readinessProbe` 는 동작하지 않음. 이 구간 동안만 길게 봐주는 것이 원칙.

```yaml
startupProbe:
  httpGet:
    path: /actuator/health
    port: 8100
  initialDelaySeconds: 30
  periodSeconds: 10
  failureThreshold: 30      # 30 + 30*10 = 최대 330초 부팅 허용
livenessProbe:
  httpGet:
    path: /actuator/health
    port: 8100
  periodSeconds: 20
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /actuator/health
    port: 8100
  periodSeconds: 10
  failureThreshold: 3
```

추가로 Jenkins 파이프라인에서 `kubectl rollout status --timeout=120s` 로 짧게 잡혀 있으면 배포 단계에서 실패로 표기되므로 함께 늘림.

```groovy
sh "/usr/bin/kubectl rollout status deployment/${env.DEPLOY_NAME} -n tomboy --timeout=360s"
```

#### 4) 핵심 원리

- `livenessProbe.initialDelaySeconds` 는 **단발성 지연**이라 부팅 시간이 들쑥날쑥하면 부적합.
- `startupProbe` 는 **부팅 단계 전용 게이트** 역할. 통과 후에는 자동으로 사라짐.
- liveness/readiness 는 **운영 중 헬스체크**가 본래 목적이므로 `initialDelaySeconds` 는 0~짧게 두는 게 정석.

#### 5) 같은 패턴 (다른 증상이 같은 원인)

| 증상 | 실제 원인 |
|------|-----------|
| `Back-off restarting failed container` 무한 반복 | startupProbe 미사용 + 부팅 시간 > liveness initialDelay |
| 배포 직후만 0/1, 시간 지나면 1/1 | 부팅 시간이 readiness initialDelay 와 비슷한 경계 |
| Jenkins `rollout status timeout` | 파이프라인의 timeout 이 startupProbe 최대 시간보다 짧음 |

---

## 한 줄 요약

```
[마스터] 버전확인+토큰 → [워커] k3s 제거 → 잔여 삭제 → swap off → 모듈/sysctl → containerd.io → kubeadm 패키지 → join → [마스터] 확인·라벨·taint·Ingress → [마스터/워커] tomboy 배포
```

---

## 참고 문서

- `linux/k3s_delete.md` — k3s 제거 및 Ubuntu 측 kubeadm 개요
- `linux/인스톨가이드_5_ml110붙이기.md` — 멀티 노드·라벨·taint 예시

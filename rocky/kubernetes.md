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

### 10-2. 컨테이너 이미지 빌드 및 워커 전송

`deployment.yaml`의 `imagePullPolicy: IfNotPresent` 설정에 의해, **워커 노드의 containerd에 이미지가 있어야** 합니다.

**[마스터] 이미지 빌드:**

```bash
# auth-server 프로젝트 루트에서
./gradlew bootWar
docker build -f deployment/Dockerfile -t auth-server:latest .
```

**[마스터] tar로 저장 → 워커로 전송:**

```bash
docker save auth-server:latest -o auth-server.tar
scp auth-server.tar kube@<워커IP>:~/
```

**[워커] containerd에 import:**

```bash
sudo ctr -n k8s.io images import ~/auth-server.tar
```

import 확인:

```bash
sudo ctr -n k8s.io images list | grep auth-server
# docker.io/library/auth-server:latest 가 표시되면 정상
```

### 10-3. ConfigMap · Secret 적용 [마스터]

> `secret.yaml`의 `DB_PASSWORD: "changeme"`를 **실제 비밀번호로 변경** 후 적용합니다.  
> `configmap.yaml`의 `DB_HOST`, `REDIS_HOST` 등 IP가 현재 환경과 맞는지 확인합니다.

```bash
kubectl apply -f deployment/k8s/configmap.yaml
kubectl apply -f deployment/k8s/secret.yaml
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

### 10-6. 확인 — k9s

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

## 한 줄 요약

```
[마스터] 버전확인+토큰 → [워커] k3s 제거 → 잔여 삭제 → swap off → 모듈/sysctl → containerd.io → kubeadm 패키지 → join → [마스터] 확인·라벨·taint·Ingress → [마스터/워커] tomboy 배포
```

---

## 참고 문서

- `linux/k3s_delete.md` — k3s 제거 및 Ubuntu 측 kubeadm 개요
- `linux/인스톨가이드_5_ml110붙이기.md` — 멀티 노드·라벨·taint 예시

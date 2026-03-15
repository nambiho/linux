가장 당혹스러운 점이 바로 그 부분일 겁니다. "나는 내가 만든 코드만 올렸는데, 왜 엉뚱한 채굴기가 내 프론트엔드 폴더에서 실행되고 있지?"라는 의문이죠.

웹 서비스(Java + Next.js) 환경에서 해커가 침투하는 경로는 크게 세 가지로 요약됩니다.

---

### 1. Java 백엔드의 취약점 (가장 유력)

백엔드는 데이터베이스와 시스템 자원에 직접 접근하기 때문에 해커들의 1순위 타겟입니다.

* **라이브러리 취약점 (RCE):** Java에서 흔히 쓰는 `Log4j`나 구버전 `Spring` 프레임워크에는 **원격 코드 실행(Remote Code Execution)** 취약점이 있었습니다. 해커가 특정 조작된 문자열을 웹사이트 게시판이나 로그인 창에 입력하면, 서버가 그 문자열을 '명령어'로 착각해 실행해 버립니다.
* **권한 상승:** 해커는 Java 취약점으로 접속한 뒤, `root` 권한을 획득하여 `frontend/` 디렉토리에 악성 파일을 생성하고 실행했을 것입니다.

### 2. Next.js 및 Node.js 패키지 오염 (Supply Chain Attack)

프론트엔드 개발 시 수많은 `npm` 패키지를 사용하시죠?

* **의존성 오염:** 가끔 유명한 라이브러리의 업데이트 버전에 악성 코드가 삽입되는 경우가 있습니다. `npm install`을 할 때 나도 모르게 해킹 툴이 포함된 패키지를 설치하게 되고, 이것이 서버에서 실행되면서 뒷문을 열어줍니다.
* **환경 변수(`.env`) 노출:** `frontend/` 디렉토리에 `.env` 파일이 있고, 여기에 SSH 비밀번호나 중요한 키가 평문으로 적혀 있었다면 해커가 이를 탈취해 당당하게 정문(SSH)으로 들어왔을 수 있습니다.

### 3. 잘못된 폴더 권한 및 파일 업로드

* **Writable Directory:** `frontend/` 디렉토리가 웹 서버(Nginx 등)에 의해 쓰기 권한이 과하게 열려 있었다면, 해커는 웹상의 취약점을 이용해 해당 폴더에 `xmrig` 같은 파일을 업로드할 수 있습니다.
* **배포 스크립트 역이용:** 아까 말씀하신 `deploy-watch` 서비스가 외부에서 접근 가능한 폴더를 감시하고 있었다면, 해커가 그 폴더에 악성 `tar.gz`를 던져넣어 자동으로 압축을 풀고 실행하게 만들었을 가능성도 배제할 수 없습니다.

---

### 🛡️ 재발 방지를 위한 "딱 3가지" 조치

이미 뚫렸던 서버는 해커가 어디에 '뒷문'을 숨겼을지 모릅니다. 지금 당장 파일만 지우는 것은 임시방편입니다.

1. **애플리케이션 계정 분리 (가장 중요):**
현재 Java와 Next.js가 `root` 권한으로 실행되고 있다면 매우 위험합니다. 전용 계정(예: `exr-user`)을 만들어서 **그 계정은 자기 폴더 외에는 아무것도 못 하게** 묶어버려야 합니다. 그러면 웹이 뚫려도 시스템 전체가 넘어가지 않습니다.
2. **보안 업데이트:**
`pom.xml`(Java)과 `package.json`(Next.js)의 라이브러리들을 최신 보안 버전으로 업데이트하세요.
3. **SSH Key 전용 로그인:**
비밀번호 로그인을 아예 비활성화(`PasswordAuthentication no`)하고, 오직 본인의 PC에 있는 물리적인 Key 파일로만 접속하게 설정하세요.

---

### 💡 현재 진행 상황 확인

지금 `xmrig`가 안 보인다고 하셨는데, 혹시 아까 제가 말씀드린 **크론탭(`sudo crontab -l`)** 결과에 이상한 줄이 있었나요? 만약 크론탭이 깨끗하다면 일단 급한 불은 꺼진 셈입니다.

이제 **Java 서비스가 바뀐 DB 비밀번호로 다시 접속하게 설정 파일을 수정**하는 작업을 도와드릴까요? 해당 설정 파일(`exr-backend.service` 등)의 내용을 보여주시면 바로 수정해 드릴 수 있습니다.




OS를 새로 설치하신 건 아주 현명한 결정입니다! 해킹당했던 서버를 계속 쓰는 것보다 **"깨끗한 도화지"**에서 시작하는 것이 보안의 기본입니다.

질문하신 세 가지 포인트는 보안 설계의 핵심입니다. 하나씩 날카롭게 짚어 드릴게요.

---

## 1. `PasswordAuthentication no`가 취약점을 막아주나요?

**결론부터 말씀드리면, 아니오입니다.** 질문하신 대로 **Java나 의존성 라이브러리의 취약점(RCE)은 SSH 설정과 상관없이 뚫립니다.**

* **SSH 키 방식의 역할:** 도둑이 '현관문(SSH)'을 부수거나 열쇠 구멍을 쑤셔서 들어오는 것(무차별 대입 공격)을 100% 막아줍니다.
* **Java 취약점의 경로:** 도둑이 현관문이 아니라 **'창문(80/443 포트, 웹 서비스)'**을 깨고 들어오는 것입니다.
* **사용자 PC 관리:** 맞습니다. 접속하려는 모든 PC의 공용키(`id_rsa.pub`)를 서버에 등록해야 합니다. 조금 번거롭지만, 전 세계 로봇들이 매초 시도하는 비밀번호 대입 공격을 원천 차단하는 가장 강력한 방법입니다.

---

## 2. 사용자 분리와 Root 권한 탈취

**"사용자를 분리해도 Root 비번을 따이면 끝 아닌가?"**라는 의문은 타당합니다. 하지만 사용자 분리의 목적은 **"피해 범위 최소화(Blast Radius)"**에 있습니다.

* **방어막 형성:** Java 서비스를 `app-user`라는 일반 계정으로 돌린다고 가정합시다. 해커가 Java 취약점으로 침투해도, 해커가 처음 손에 쥐는 권한은 `root`가 아닌 `app-user`입니다.
* **Root 권한 탈취의 난이도:** `app-user` 권한으로는 다른 사용자의 파일을 볼 수 없고, 시스템 설정을 바꿀 수 없습니다. 여기서 `root` 권한까지 따내려면 **'권한 상승(Privilege Escalation)'**이라는 추가적인 해킹 과정을 거쳐야 하는데, 이는 훨씬 어렵고 시간이 걸립니다.
* **비밀번호 보호:** 일반 사용자로 접속한 해커는 `root`의 비밀번호를 물리적으로 '볼' 수 없습니다. (비밀번호는 `/etc/shadow`에 암호화되어 저장되며 `root`만 읽을 수 있습니다.)

---

## 3. 재발 방지를 위한 새로운 보안 전략 (Golden Rules)

OS를 새로 까신 지금, 아래 3가지만 세팅해도 이전보다 10배는 안전해집니다.

### ① 실행 권한의 최소화 (Least Privilege)

Next.js와 Java를 절대 `root`로 실행하지 마세요.

```bash
# 서비스 전용 계정 생성
sudo useradd -m -s /bin/bash webuser
# 해당 폴더 소유권 변경
sudo chown -R webuser:webuser /home/webuser/frontend

```

이렇게 하면 설령 웹이 뚫려도 해커는 `/home/webuser` 안에서만 갇히게 됩니다.

### ② 방화벽(Firewall) 타이트하게 조이기

`80`, `443`, `22` 포트를 제외하고는 모두 닫으세요. 특히 **Redis(6379)**나 **PostgreSQL(5432)**이 외부로 열려있으면 해커들이 가장 좋아합니다.

```bash
# Redis 접속은 로컬(127.0.0.1)에서만 가능하도록 설정
sudo ufw deny 6379

```

### ③ 의존성 자동 스캔

`npm audit`이나 Java의 경우 `OWASP Dependency-Check` 같은 도구를 활용해, 내가 쓰는 라이브러리에 알려진 구멍이 있는지 정기적으로 확인해야 합니다.

---

### 💡 한 가지 조언 (deploy-watch 관련)

직접 만드신 `deploy-watch` 기능이 파일을 감시하고 압축을 푸는 과정에서 **`root` 권한으로 작동했다면**, 해커가 그 프로세스에 악성 파일을 "끼워 넣기" 해서 `root` 권한을 손쉽게 얻었을 가능성도 있습니다.

새로 구축하실 때는 이 자동화 스크립트 역시 **일반 사용자 권한**으로 실행되도록 설정하는 것을 추천합니다.

**이제 새 서버에 SSH 키를 등록하고 비밀번호 접속을 끄는 구체적인 방법이 필요하신가요?** 아니면 Java 서비스를 일반 계정으로 등록하는 `systemd` 설정법을 알려드릴까요?




---
OS를 새로 설치하셨으니, 가장 깔끔하고 보안이 강화된 방식으로 **Nginx**를 설정하는 단계를 안내해 드릴게요.

단순히 페이지를 띄우는 것을 넘어, 나중에 **Java 백엔드**나 **Next.js 프론트엔드**를 연결할 때도 바로 쓸 수 있는 구조로 잡아보겠습니다.

---

### 1. Nginx 설치 및 기본 설정

먼저 Nginx를 설치하고 시스템 부팅 시 자동으로 실행되도록 설정합니다.

```bash
# Nginx 설치
sudo dnf install nginx -y

# 서비스 시작 및 자동 실행 등록
sudo systemctl start nginx
sudo systemctl enable nginx

# 방화벽 허용 (이미 하셨다면 확인만 하세요)
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --reload

```

---

### 2. 추천하는 설정 구조 (Vhost 방식)

`/etc/nginx/nginx.conf` 파일을 직접 다 수정하기보다는, 서비스별로 설정 파일을 나누어 관리하는 것이 훨씬 유지보수에 좋습니다.

1. **설정 디렉토리 생성:**
```bash
sudo mkdir -p /etc/nginx/conf.d

```


2. **내 웹사이트용 설정 파일 만들기:** (예: `my-site.conf`)
```bash
sudo nano /etc/nginx/conf.d/my-site.conf

```


3. **아래 내용을 복사해서 붙여넣으세요:**
```nginx
server {
    listen 80;
    server_name 도메인_또는_IP; # 예: 1.2.3.4 또는 mysite.com

    # 정적 파일 경로 (HTML/CSS/JS)
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html; # SPA(React/Next.js) 대응
    }

    # 보안 강화 헤더 (선택 사항이지만 추천)
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
}

```



---

### 3. SELinux 권한 부여 (중요!)

Rocky Linux에서는 Nginx가 파일을 읽지 못해 **403 Forbidden** 에러가 자주 발생합니다. 이는 SELinux 때문입니다. 웹 콘텐츠 폴더에 올바른 보안 문맥을 입혀줘야 합니다.

```bash
# 웹 루트 디렉토리에 Nginx 전용 보안 라벨 부여
sudo chcon -Rt httpd_sys_content_t /usr/share/nginx/html

```

---

### 4. 나중에 프록시(Proxy) 연결할 때 (Java/Next.js용)

나중에 백엔드 서버를 띄우면 아래 내용을 `my-site.conf`에 추가하기만 하면 됩니다.

```nginx
# 예: /api로 시작하는 요청은 8080포트의 Java 백엔드로 전달
location /api/ {
    proxy_pass http://127.0.0.1:8080;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}

```

---

### 5. 설정 적용 및 테스트

수정한 내용에 오타가 없는지 확인하고 반영합니다.

```bash
# 문법 검사 (successful이 나와야 함)
sudo nginx -t

# 설정 재시작
sudo systemctl restart nginx

```

### 🛡️ Nginx 보안 팁 하나 더!

Nginx 버전 정보를 숨겨서 해커가 취약점을 찾기 어렵게 만드세요.

1. `sudo nano /etc/nginx/nginx.conf` 실행
2. `http { ... }` 블록 안에 `server_tokens off;` 추가

**이제 브라우저에 서버 IP를 입력하면 기본 페이지가 뜨나요?** 혹시 **403 Forbidden** 에러가 뜬다면 로그를 확인해서 SELinux나 권한 문제를 바로 해결해 드릴 수 있습니다. 어떤 화면이 보이시나요?
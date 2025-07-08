`dnf`에서 \*\*설치된 패키지 목록(installed list)\*\*을 확인하려면 아래 명령어를 사용하면 됩니다:

---

### ✅ 설치된 패키지 전체 보기

```bash
dnf list installed
```

출력 예시:

```
Installed Packages
bash.x86_64         5.1.8-6.el9        @baseos
coreutils.x86_64    8.32-27.el9        @baseos
dnf.noarch          4.10.0-2.el9       @baseos
```

* `@baseos`는 어떤 저장소로부터 설치되었는지를 나타냅니다.

---

### 🔍 특정 패키지가 설치되었는지 확인

```bash
dnf list installed <패키지명>
```

**예시:**

```bash
dnf list installed java*
```

이렇게 하면 `java`로 시작하는 설치된 패키지를 확인할 수 있습니다.

---

### 🔍 설치된 패키지에서 필터링 (grep)

```bash
dnf list installed | grep openjdk
```

---

### 📦 설치된 패키지 수 확인

```bash
dnf list installed | wc -l
```

---

필요하면 설치된 패키지를 파일로 저장할 수도 있습니다:

```bash
dnf list installed > installed-packages.txt
```

---

더 궁금한 게 있거나 특정 패키지 관리 작업이 필요하면 알려 주세요!

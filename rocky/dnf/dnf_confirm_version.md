`Rocky Linux`에서 `dnf` 명령어를 사용하여 **저장소에 있는 소프트웨어의 버전 정보**를 확인하는 방법은 다음과 같습니다:

---

### 🔍 1. 특정 패키지의 저장소 내 가용 버전 확인

```bash
dnf --showduplicates list <패키지명>
```

**예시:**

```bash
dnf --showduplicates list java-1.8.0-openjdk
```

이 명령은 현재 설치된 버전 외에 저장소에 존재하는 모든 버전을 출력해줍니다.

---

### 🔍 2. `dnf`를 이용한 버전 검색 (`available` 항목만 보기)

```bash
dnf list --available <패키지명>
```

**예시:**

```bash
dnf list --available java*
```

---

### 🔍 3. `dnf info`를 통해 상세 정보 확인

```bash
dnf info <패키지명>
```

**예시:**

```bash
dnf info java-11-openjdk
```

출력 내용에는 패키지 설명, 버전, 릴리즈, 저장소 정보 등이 포함됩니다.

---

### 🔍 4. 특정 저장소에서만 검색하고 싶다면

```bash
dnf --disablerepo="*" --enablerepo="<저장소이름>" list available <패키지명>
```

**예시:**

```bash
dnf --disablerepo="*" --enablerepo="epel" list available htop
```

---

### ✅ 보충: `dnf module` 사용하는 경우 (특히 Java, PHP 등 모듈 기반 패키지)

```bash
dnf module list java
```

출력 결과:

```
Name  Stream         Profiles                                Summary
java  8 [d], 11, 17  common, development, headless, minimal  Java Implementation
```

* `Stream`은 지원되는 주요 버전입니다.
* `[d]`는 default stream을 의미합니다.

---

필요하다면, 특정 모듈 스트림을 활성화 후 설치도 가능:

```bash
dnf module enable java:11
dnf install java-11-openjdk
```

---

궁금한 패키지 이름이 정확하지 않다면 `dnf search`로 먼저 찾아보는 것도 좋습니다:

```bash
dnf search openjdk
```

---

필요한 패키지나 버전이 있다면 말씀 주세요. 설치용 저장소나 방법도 같이 도와드릴 수 있어요.

# ClassFlow

학원 운영과 수업 공유를 지원하는 서비스입니다. 학원 관리자와 선생님이 학원 및 학생 정보를 관리하고, 출결·원비 납부·수업 내용을 기록할 수 있습니다. 수업 내용은 기간별 공개 링크로 학부모와 공유할 수 있습니다.

## 제품 목표

- 학원 운영에 필요한 정보를 한곳에서 관리합니다.
- 관리자와 선생님이 역할에 맞게 학원 업무를 처리할 수 있도록 합니다.
- 수업 내용을 기간별로 정리하고, 학부모가 공개 링크를 통해 확인할 수 있도록 합니다.

## 지원 영역

- **Flutter 앱**: 모바일 환경에서 학원 운영 및 수업 관련 기능 제공
- **Web**: 웹 환경에서 학원 운영 및 수업 관련 기능 제공
- **다국어**: 사용자 인터페이스와 주요 서비스 콘텐츠의 다국어 지원

지원 플랫폼과 언어의 구체적인 범위는 추후 확정합니다.

## 사용자 및 권한

### 학원 관리자 (Principal)

학원의 운영을 총괄합니다.

- 학원 정보 조회 및 관리
- 소속 선생님 정보와 고용 인원 관리
- 출석부 관리
- 원비 납부 내역 관리
- 수업 및 수업 내용 관리
- 학생 정보 관리
- 기간별 수업 내용을 공개 링크로 공유

### 선생님 (Teacher)

담당 업무와 권한 범위 내에서 학원 운영 및 수업 정보를 관리합니다.

- 출석부 관리
- 원비 납부 내역 관리
- 수업 및 수업 내용 관리
- 학생 정보 관리
- 기간별 수업 내용을 공개 링크로 공유

세부 권한 범위와 관리자 승인 여부는 추후 확정합니다.

## 주요 기능

### 학원 및 선생님 관리

- Principal은 학원 정보를 관리할 수 있습니다.
- Principal은 학원에 소속된 Teacher 정보를 관리할 수 있습니다.
- 사용자는 소속 학원과 역할에 따라 이용 가능한 정보를 확인할 수 있습니다.

### 학생 정보 관리

- 학생 정보를 등록하고 조회할 수 있습니다.
- 학생 정보를 수정하거나 관리할 수 있습니다.
- 학원 및 수업 운영에 필요한 학생 정보를 관리합니다.

### 출석 관리

- 학생 출석 정보를 기록하고 조회할 수 있습니다.
- 학원과 선생님은 필요한 출석 정보를 관리할 수 있습니다.

### 원비 납부 내역 관리

- 학생별 원비 납부 내역을 기록하고 조회할 수 있습니다.
- 학원과 선생님은 필요한 납부 정보를 관리할 수 있습니다.

### 수업 관리

- 수업 정보를 등록하고 조회할 수 있습니다.
- 수업에서 다룬 내용을 기록하고 관리할 수 있습니다.
- 기록된 수업 내용을 기간별로 확인할 수 있습니다.

### 수업 내용 공유

- 사용자는 지정한 기간의 수업 내용을 공개 링크로 공유할 수 있습니다.
- 예를 들어, 월별 수업 내용을 하나의 링크로 학부모에게 제공할 수 있습니다.
- 링크를 받은 학부모는 계정 생성이나 로그인 없이 해당 기간의 공개된 수업 내용을 확인할 수 있습니다.
- 공개 링크의 만료, 접근 제한, 공유 가능한 정보 범위는 추후 정책으로 확정합니다.

## 공통 요구사항

- Flutter 앱과 Web에서 핵심 기능을 이용할 수 있어야 합니다.
- 사용자에게 표시되는 주요 화면과 콘텐츠는 다국어를 지원해야 합니다.
- 사용자는 자신의 역할과 소속 학원에 맞는 정보만 관리하고 조회할 수 있어야 합니다.
- 학부모 공개 링크에는 공유 대상으로 지정된 수업 내용만 표시해야 합니다.

## 추후 결정할 항목

- 지원할 언어와 기본 언어
- Teacher의 세부 권한 및 데이터 접근 범위
- 출석 및 원비 납부 내역의 필수 입력 항목
- 공개 링크의 만료 기간, 비밀번호 설정 및 재발급 정책
- Flutter 앱과 Web의 기능 차이 여부
- 알림, 결제 연동 등 추가 기능의 범위

## 개발 환경

- Flutter stable `3.47.6` 이상 및 Dart `3.13.5` 이상
- Android, iOS, Web 타깃은 저장소의 Flutter scaffold를 사용합니다.
- iOS scaffold의 Bundle ID `com.wonder13662.classflow`는 개발용 임시 식별자입니다. Firebase iOS 앱 등록, 프로비저닝 또는 배포 서명 전에 확정된 Bundle ID와 Apple Team ID로 교체하세요.

### 환경 설정

스크립트 환경 이름은 `dev`, `stage`, `prod`이며 앱에는 각각 `CLASSFLOW_ENV=development`, `stage`, `production`으로 전달됩니다. 직접 Flutter 명령을 실행할 때도 같은 define 값을 사용합니다. 다른 값은 앱 시작 시 오류가 됩니다.

기본 `debug` 실행은 Firebase와 RevenueCat 설정 파일 없이도 가능합니다. Firebase 설정이 없으면 앱은 Firebase 초기화를 건너뜁니다. 예제 값을 채운 임시 설정 파일을 만들 필요는 없습니다.

Firebase를 추후 연동할 때는 환경 및 플랫폼별 JSON define 파일을 추가합니다. 저장소의 `config/firebase/<environment>/<platform>.example.json`을 복사해 `.json` 파일을 만들고 Firebase 프로젝트의 실제 값을 입력하세요. 예를 들어 개발용 iOS는 `config/firebase/development/ios.json`, Web은 `config/firebase/development/web.json`입니다. 필수 키는 `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_PROJECT_ID`입니다. 플랫폼에 따라 `FIREBASE_IOS_BUNDLE_ID`, `FIREBASE_AUTH_DOMAIN`, `FIREBASE_STORAGE_BUCKET` 등의 값을 추가할 수 있습니다. 같은 실행 명령을 다시 실행하면 파일이 자동으로 검증 및 전달되고 앱이 Firebase를 초기화합니다. iOS Bundle ID는 등록한 Firebase 앱과 일치해야 하며, 인증·푸시 등 개별 기능에는 별도 플랫폼 설정이 필요할 수 있습니다.

RevenueCat define 파일도 `config/revenuecat/<environment>.example.json`을 복사해 `<environment>.json`으로 만들고 `REVENUECAT_API_KEY`를 설정합니다. 이 프로젝트는 키를 검증하고 앱에 define으로 전달하지만 RevenueCat SDK를 초기화하거나 결제를 수행하지 않습니다. 실제 설정 파일은 Git에서 제외됩니다.

### 실행, 빌드, 테스트

```sh
flutter pub get
./tool/run.sh
./tool/run.sh dev android
./tool/run.sh stage ios --device-id=<device-id>
./tool/run.sh dev web
./tool/build.sh dev android
./tool/build.sh prod ios release
./tool/build.sh stage web
./tool/test_flutter.sh
python3 -m unittest discover -s test/tool -p '*_test.py' -v
dart format lib test
dart analyze
```

`run.sh`의 `debug` 실행은 없는 서비스 설정 파일만 생략합니다. 파일이 있으면 JSON 형식과 필수 값을 검증하므로, 잘못된 설정이나 예제 값이 남아 있으면 실행이 중단됩니다. Firebase와 RevenueCat은 각각 독립적으로 추가할 수 있습니다. `run.sh --release` 실행과 `build.sh`는 기존처럼 두 설정 파일을 모두 요구합니다.

환경과 플랫폼은 생략할 수 있으며 기본값은 각각 `dev`, `ios`입니다. `./tool/run.sh`는 `./tool/run.sh dev ios`와 같고, `./tool/run.sh stage`는 `stage ios`로 실행합니다. 옵션만 지정하는 `./tool/run.sh --debug`도 가능합니다. Web에는 Android/iOS flavor 옵션을 전달하지 않습니다.

VS Code 상태 표시줄에서 선택한 기기를 사용하려면 명령 팔레트의 `Tasks: Run Task`에서 `ClassFlow: Run`을 실행하세요. 이 task는 Flutter 확장의 선택 기기 ID를 스크립트 인자로 전달합니다. 직접 통합 터미널에서 실행할 때는 VS Code 선택값이 자동 전달되지 않으므로, `CLASSFLOW_DEVICE_ID=<device-id> ./tool/run.sh` 또는 `./tool/run.sh --device-id=<device-id>`를 사용하세요. 우선순위는 `--device-id`, VS Code task의 선택 기기, `CLASSFLOW_DEVICE_ID`, 플랫폼 지원 기기 중 첫 번째 자동 선택 순입니다. 선택 및 자동 선택 기기는 ID와 이름을 출력하며, Web 기본 기기는 Chrome입니다.

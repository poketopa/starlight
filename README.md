# Starlight

Starlight는 집중 중인 앱은 밝게 유지하고, 주변 창을 부드럽게 어둡게 만들어 주는 macOS 메뉴 막대 앱입니다.

## 주요 기능

- 현재 사용 중인 앱과 최근 사용한 앱 강조
- 배경 창 dimming
- 밝기, 색상, 애니메이션 속도 설정
- 메뉴 막대 아이콘으로 빠른 제어
- 단축키 지원: `Control + Option + Command + F`
- 다중 디스플레이 지원
- macOS 접근성 권한 기반 창 감지

## 설치

### Homebrew

```sh
brew install --cask poketopa/starlight/starlight
```

업데이트:

```sh
brew upgrade --cask starlight
```

### GitHub Releases

최신 버전은 [GitHub Releases](https://github.com/poketopa/starlight/releases/latest/download/Starlight.zip)에서 다운로드할 수 있습니다.

### 터미널 설치

```sh
curl -fsSL https://raw.githubusercontent.com/poketopa/starlight/main/install.sh | bash
```

설치 후 처음 실행하면 macOS 접근성 권한을 허용해야 정상적으로 동작합니다.

## 개발

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
scripts/build-app.sh
open dist/Starlight.app
```

---

# Starlight

Starlight is a native macOS menu bar app that keeps your focused apps visible while gently dimming distracting background windows.

## Features

- Highlights active and recently used apps
- Dims background windows
- Adjustable dimming intensity, color, and animation speed
- Menu bar control
- Shortcut: `Control + Option + Command + F`
- Multi-display support
- Accessibility-based window tracking

## Install

### Homebrew

```sh
brew install --cask poketopa/starlight/starlight
```

### GitHub Releases

Download the latest build from [GitHub Releases](https://github.com/poketopa/starlight/releases/latest/download/Starlight.zip).

### Terminal

```sh
curl -fsSL https://raw.githubusercontent.com/poketopa/starlight/main/install.sh | bash
```

Starlight requires macOS Accessibility permission to track windows correctly.

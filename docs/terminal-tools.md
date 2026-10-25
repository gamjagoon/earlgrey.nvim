# Zellij와 GitUI 단축키

`dotfile/`에 있는 Zellij·GitUI 설정을 설명합니다. Neovim 설치 스크립트는 이
파일들을 설치하지 않습니다. Unix와 WSL에서는 `$XDG_CONFIG_HOME`이 설정되어
있으면 그 경로를, 아니면 `$HOME/.config`를 사용합니다.

## Zellij

Zellij는 기본 `default` 레이아웃과 `locked` 모드로 시작합니다. 기본 레이아웃은
위쪽에 탭 바, 아래쪽에 상태 표시줄을 표시합니다. 잠긴 상태에서는 입력이 셸이나
Neovim으로 전달되며, 상태 표시줄에서 잠금 해제 단축키를 확인할 수 있습니다.
`Ctrl+g`를 눌러 Normal 모드로 전환하면 모드별 단축키가 표시되고, 다시 누르면
잠깁니다.
기본 테마는 Neovim에서 선택한 Evergarden `winter` 변형의 색을 반영한
`evergarden-winter`입니다. `evergarden-spring`, `evergarden-summer`,
`evergarden-fall`도 설치된 Neovim Evergarden 팔레트의 색을 사용합니다. 팔레트
기준으로 spring/fall은 어두운 배경, summer는 밝은 배경입니다. 기존 Dracula,
One Dark, Tokyo Night Dark 테마도 그대로 선택할 수 있습니다.

| 테마 | 배경 |
| --- | --- |
| `evergarden-winter` | 어두움, 기본값 |
| `evergarden-spring` | 어두움 |
| `evergarden-fall` | 어두움 |
| `evergarden-summer` | 밝음 |
| `dracula` | 어두움 |
| `onedark` | 어두움 |
| `tokyo-night-dark` | 어두움 |

테마별로 세션을 시작할 때는 `options --theme`에 위 표의 이름을 지정합니다.
예를 들어 summer 팔레트를 선택하려면 다음처럼 실행합니다. 옵션을 생략한 새 세션은
`evergarden-winter`를 사용합니다.

```sh
zellij -c "$PWD/dotfile/zellij/config.kdl" options --theme evergarden-summer
```

| 단축키 | 동작 |
| --- | --- |
| `Ctrl+g` | Normal 모드로 전환하거나 잠금 |
| `Alt+h/j/k/l` | 잠금 해제 후 패널 포커스를 이동. 좌우 가장자리에서는 이전/다음 탭으로 이동 |
| `Alt+f` | 잠금 해제 후 포커스된 패널을 전체 화면으로 전환 |
| `Alt+w` | 잠금 해제 후 플로팅 패널 표시 전환 |
| `Ctrl+g`, `Ctrl+p`, `h/j/k/l` | 패널 모드에서 포커스 이동 |
| `Ctrl+g`, `Ctrl+t`, `h` / `l` | 탭 모드에서 이전/다음 탭으로 이동 |
| `Ctrl+g`, `Ctrl+h`, `h/j/k/l` | 패널 이동 모드에서 패널 위치 변경 |

일반 탐색 모드에서는 `Enter` 또는 `Esc`로 Normal 모드에 돌아옵니다. 검색·이름
입력 모드는 `Enter`와 `Esc`를 각각 별도로 처리합니다.

## GitUI

| 단축키 | 동작 |
| --- | --- |
| `h/j/k/l` | 왼쪽/아래/위/오른쪽 이동 |
| `g` / `G` | 목록의 처음/끝으로 이동 |
| `s` | 선택한 diff 줄을 stage |
| diff 화면의 `Ctrl+r` | 선택한 diff 줄 reset |
| 브랜치 팝업의 `Ctrl+r` | 원격 저장소 보기 |
| `Shift+O` | 선택한 stash 열기 |
| `Shift+U` | 선택한 상태 항목 reset |

## 저장소 설정 미리 실행

저장소 루트에서 명령을 실행하면 사용자 설정을 덮어쓰지 않고 저장소 파일로
프로그램을 실행합니다.

```sh
zellij -c "$PWD/dotfile/zellij/config.kdl"
gitui -k "$PWD/dotfile/gitui/key_bindings.ron"
```

## 직접 설치

Unix 또는 WSL의 Bash에서 `repo_root`를 저장소 경로로 바꾸고 아래 명령을
실행합니다. 기존 파일은 덮어쓰기 전에 시각이 붙은 백업으로 보존합니다.

```sh
repo_root=/path/to/earlgrey.nvim
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
backup_stamp=$(date +%Y%m%d-%H%M%S)-$$

install_config() {
  local relative_path="$1"
  local destination="$config_root/$relative_path"
  mkdir -p "$(dirname "$destination")"
  if [ -e "$destination" ]; then
    cp -a "$destination" "$destination.bak.$backup_stamp"
  fi
  cp "$repo_root/dotfile/$relative_path" "$destination"
}

install_config zellij/config.kdl
install_config gitui/key_bindings.ron
```

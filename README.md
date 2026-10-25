<div align="center">

# earlgrey.nvim

**얼그레이 네오빔 · A warm cup. A focused editor.**

<img src="docs/assets/earlgrey-tea.png" alt="A steaming cup of amber Earl Grey tea with bergamot and tea leaves on a forest-green background" width="960">

차 한 잔의 여유로, 코드에 몰입하는 Neovim.

![Neovim 0.12+](https://img.shields.io/badge/Neovim-0.12%2B-536B4F?style=flat-square&logo=neovim&logoColor=white)

</div>

## 소개

Space 단축키, FzfLua 검색, Blink 자동 완성, Markdown 렌더링, Rust·Python 개발 도구를 갖춘 개인용 Neovim 설정입니다. 플러그인은 lazy.nvim으로 관리합니다.

## 설치

Neovim **0.12 이상**이 필요합니다. 설치기는 Git, 컴파일 도구, `tree-sitter` CLI, `fd`, `rg`, `fzf` 등 필요한 도구와 설정을 설치합니다. 인터넷 연결이 필요하며 Linux에서 시스템 패키지를 설치할 때는 `sudo` 권한이 필요합니다.

저장소를 받은 뒤 운영체제에 맞는 설치기를 실행하세요.

```sh
git clone https://github.com/gamjagoon/earlgrey.nvim.git
cd earlgrey.nvim

# Linux
bash script/install-linux.sh

# macOS
bash script/install-macos.sh
```

Windows 10/11에서는 PowerShell 5.1 이상과 WinGet이 필요합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\script\install-windows.ps1 -InstallTools
```

기존 Neovim 설정은 설치 전에 날짜가 붙은 백업으로 보존합니다. Linux/macOS는 설정을 연결하고, Windows는 복사합니다.

## 자주 쓰는 단축키

Leader 키는 `Space`입니다.

| 단축키 | 동작 |
| --- | --- |
| `Ctrl-h/j/k/l` | 창 이동 |
| `Shift-h/l` | 이전·다음 버퍼 |
| `Space 1` … `Space 9` | 번호로 버퍼 선택 |
| `Space e` | 파일 트리 열기·닫기 |
| `Space ff` | 파일 찾기 |
| `Space fg` | 파일 내용 검색 |
| `Space /` | 현재 버퍼 검색 |

## 자세한 안내

- [전체 설정·설치·단축키 안내](docs/guide.md) (한국어 · English · 日本語)
- [Windows 설치와 도구 설정](docs/windows-setup.md)
- [LSP 설정](docs/lsp.md)
- [에이전트 완료 알림](docs/agent-notifications.md)
- [터미널 도구](docs/terminal-tools.md)

English and Japanese readers: see the [English guide](docs/guide.md#english) and [日本語ガイド](docs/guide.md#japanese).

# 언어별 LSP 설정

`nvim/lua/lsp_languages.lua`의 `enabled`를 수정하면 다음 Neovim 실행부터
기본값이 적용됩니다. 기본값은 아래 언어 모두 `true`입니다. 서버 설치와
활성화는 별개이므로 실행 파일이 `PATH`에 있어야 실제로 연결됩니다.

| 언어 인수 | 서버 | 실행 파일 | 파일 형식 |
| --- | --- | --- | --- |
| `c`, `cpp` | clangd | `clangd` | C, C++ |
| `rust` | rustaceanvim | `rust-analyzer` | Rust |
| `python` | Pyright | `pyright-langserver` | Python |
| `shell` | bashls | `bash-language-server` | Bash, sh |
| `makefile` | autotools_ls | `autotools-language-server` | Makefile, Automake, Autoconf |

C와 C++는 서버 하나를 공유합니다. `LspDisable c`는 C++에도 적용됩니다.
시작 기본값을 바꿀 때도 `c.enabled`와 `cpp.enabled`를 같은 값으로 설정하세요.
다르게 설정하면 시작 시 설정 오류로 알려줍니다.

```lua
-- nvim/lua/lsp_languages.lua에서 해당 항목 수정
python = {
  server = 'pyright', client = 'pyright', executable = 'pyright-langserver',
  enabled = false,
},
```

## 실행 중 변경

```vim
:LspDisable rust
:LspEnable python
:LspToggle shell
:LspDisable c
:LspEnable cpp
:LspStatus
:LspStatus makefile
```

- `LspEnable`, `LspDisable`, `LspToggle`은 언어 인수 하나가 필수입니다.
- `LspStatus`는 인수가 없으면 전체 상태를, 언어 하나를 주면 해당 상태를 표시합니다.
- 언어 이름은 Tab으로 완성할 수 있습니다. 잘못된 이름과 복수 인수는 오류로 안내합니다.
- 변경은 현재 Neovim 프로세스 전체에 적용됩니다. 다른 Neovim 창에는 적용되지 않으며,
  설정 파일에 저장하지 않습니다.
- 끄면 해당 서버의 연결을 종료하고 새 버퍼에서의 자동 연결도 차단합니다.
  켜면 이미 열려 있는 해당 언어 버퍼에도 연결을 시도합니다. 연결과 종료는 비동기입니다.
- `enabled`는 연결 허용 상태입니다. 상태의 `missing`은 실행 파일 부재를 뜻하며,
  프로젝트 루트 탐색과 서버 초기화가 끝나야 활성 클라이언트가 나타납니다.

Rust는 기존 rustaceanvim 시작/종료 경로를 사용하므로 `RustLsp` 명령과 Rust 전용
단축키를 유지합니다. 다른 언어는 Neovim의 `vim.lsp.enable()`로 제어합니다.
직접 실행하는 `RustLsp`/`vim.lsp.start()` 등으로 이 관리 경로를 우회하지 마세요.

이 설정은 LSP 자동 완성·진단·정의 이동 등에 적용됩니다. Treesitter 구문 강조,
Rust의 rustfmt 저장 시 포매팅, 별도 포매터는 각각의 설정을 따릅니다.

## 서버 설치

기존 설치기는 Rust/Python 서버를 설치합니다. C/C++, Shell, Makefile 서버는
필요할 때 추가하세요. 토글 명령은 패키지를 설치하거나 제거하지 않습니다.

- C/C++: 배포판의 clangd 패키지 또는 [clangd 공식 설치 안내](https://clangd.llvm.org/installation)를
  따르세요. Windows의 LLVM-MinGW 컴파일러와 clangd 언어 서버는 별도 도구입니다.
  프로젝트에 `compile_commands.json`을 제공하면 정확한 컴파일 옵션을 사용할 수 있습니다.
- Rust: `rustup component add rust-analyzer`. Windows에서는 기존
  [windows-gnullvm 설치 안내](windows-setup.md)의 도구 체인을 사용하세요.
- Python: `npm install -g pyright`.
- Shell: `npm install -g bash-language-server`. 지원 대상은 Bash/sh이며 PowerShell은 포함하지 않습니다.
- Makefile: `pipx install autotools-language-server`. `pipx`가 없다면 먼저 설치하고
  `pipx ensurepath`로 실행 경로를 추가하세요. 별도 Python 가상 환경에서
  `python -m pip install autotools-language-server`로 설치하고 해당 환경의 실행 경로를
  `PATH`에 넣어도 됩니다.

Windows의 npm `.cmd` 실행 파일은 Python과 Shell 모두 `cmd.exe`를 통해 실행합니다.
설치 후에는 필요한 실행 경로가 반영된 터미널에서 Neovim을 다시 여세요.
서버가 설치되어 있어도 지원하는 파일 형식과 프로젝트 루트 조건에 따라 연결 시점이
달라질 수 있습니다. Makefile 서버의 루트 기준에는 `Makefile`, `Makefile.am`,
`configure.ac`, `*.mk`가 포함됩니다.

설정 API와 기본 서버 정의는 [Neovim LSP 문서](https://neovim.io/doc/user/lsp) 및
[nvim-lspconfig 서버 목록](https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.txt)을 참고하세요.

## 테스트

설정과 플러그인이 설치된 환경에서 다음 명령을 실행합니다.

```sh
nvim --headless '+luafile tests/test_config.lua' '+qa!'
nvim --headless '+luafile tests/test_compat.lua' '+qa!'
nvim --headless -c 'autocmd VimEnter * ++once luafile tests/test_lsp.lua'
```

`test_lsp.lua`는 시작 완료 후 실행하며 성공 시 종료, 실패 시 비정상 종료합니다.
Node.js와 Cargo가 필요합니다. Node.js 기반 테스트용 LSP 프로세스로 실제 연결·종료·재연결과
Rust 전용 요청을 검증합니다. 각 실제 언어 서버의 분석 정확도나 Windows 네이티브
프로세스 실행까지 검증하는 테스트는 아닙니다.

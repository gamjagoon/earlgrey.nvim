# earlgrey.nvim 공유 준비

커뮤니티에 복사해 사용할 소개문과 첫 사용자 피드백 안내입니다.
GitHub 소개·태그와 MIT 라이선스·미디어를 반영했고, [awesome-neovim 등록 PR #2571](https://github.com/rockerBOO/awesome-neovim/pull/2571)을 제출했습니다. 자동 검사 7개는 통과했으며, 병합은 유지관리자 검토 대기 중입니다.
아래 글은 초안이며 Reddit·OKKY에는 연결된 게시 계정이 없어 게시하지 않았습니다.

## 소개할 내용

**별도 터미널의 AI 에이전트 알림을 받는 Neovim 설정.**

AI 에이전트는 익숙한 터미널에서 실행하고, 코드 편집은 Neovim에서 이어가는
사용자를 대상으로 합니다. 언어별 LSP 켜기·끄기·상태 확인도 제공합니다.
FzfLua 검색, Blink 자동 완성, Markdown 구문 강조와 이미지 미리보기는 함께 쓰는 기본 도구입니다.

- Claude Code·Pi: 완료 및 지원되는 질문·입력 요청 알림.
- jcode: 턴 완료 알림. 별도의 질문 대기 이벤트는 지원하지 않습니다.
- 완료 알림은 에이전트의 응답 종료를 뜻하며 작업 성공이나 테스트 통과를 보장하지 않습니다.
- Neovim 0.12 이상이 필요합니다. Linux에서 사용했으며 macOS·Windows 설치기는
  모의 테스트까지 확인했습니다. 네이티브 macOS·Windows 실사용은 미검증입니다.
- 에이전트 hook 설치기는 Linux·WSL·macOS용입니다. 네이티브 Windows hook 설치는 지원하지 않습니다.

## 공개 자료

- [프로젝트와 설치 안내](https://github.com/gamjagoon/earlgrey.nvim)
- [실제 실행 화면](assets/earlgrey-promo-screenshot.png)
- [터미널 데모](assets/earlgrey-promo-demo.gif)
- [촬영 방식과 시연 범위](assets/README.md)
- [에이전트 hook 설정](agent-notifications.md)
- [언어별 LSP 제어](lsp.md)
- [MIT 라이선스](../LICENSE). 플러그인 등 외부 구성 요소는 각자의 라이선스를 따릅니다.

데모의 알림은 시연용 이벤트입니다. 실제 에이전트 작업 완료나 모든 운영체제에서의
실행을 입증하는 영상으로 소개하지 않습니다.

## 한국어 게시 초안

### 제목

earlgrey.nvim — 별도 터미널의 AI 에이전트 알림을 받는 Neovim 설정

### 본문

개인용 Neovim 설정 [earlgrey.nvim](https://github.com/gamjagoon/earlgrey.nvim)을 공유합니다.

AI 에이전트는 별도 터미널에서 실행하고, 코드는 Neovim에서 편집하는 흐름에 맞췄습니다.
Claude Code와 Pi의 완료·지원되는 입력 요청을 Neovim 알림으로 받을 수 있습니다.
jcode는 턴 완료 알림을 지원합니다. 언어별 LSP를 실행 중에 켜고 끄는 명령도 넣었습니다.

[실제 화면](https://github.com/gamjagoon/earlgrey.nvim/blob/main/docs/assets/earlgrey-promo-screenshot.png) ·
[짧은 데모](https://github.com/gamjagoon/earlgrey.nvim/blob/main/docs/assets/earlgrey-promo-demo.gif)

Neovim 0.12 이상이 필요합니다. Linux에서 사용 중이며 macOS·Windows 네이티브
실행은 아직 검증하지 않았습니다. 데모의 에이전트 알림은 시연용 이벤트입니다.

처음 설치해 볼 분 3~5명의 의견을 받고 싶습니다. 설치가 막힌 단계나 이해하기
어려운 단축키가 있다면 [첫 사용 피드백](https://github.com/gamjagoon/earlgrey.nvim/issues/new?template=first-run.yml)으로 알려주세요.

## English post draft

### Title

earlgrey.nvim — notifications from terminal agents while you edit

### Body

Sharing my personal Neovim setup, [earlgrey.nvim](https://github.com/gamjagoon/earlgrey.nvim).

I keep agents in separate terminals and edit in Neovim. This configuration can show
completion and supported input-needed notifications from Claude Code and Pi;
jcode notifications indicate turn completion. It also includes per-language
commands to enable, disable, and inspect LSP support.

[Screenshot](https://github.com/gamjagoon/earlgrey.nvim/blob/main/docs/assets/earlgrey-promo-screenshot.png) ·
[Short demo](https://github.com/gamjagoon/earlgrey.nvim/blob/main/docs/assets/earlgrey-promo-demo.gif)

Requires Neovim 0.12+. I use it on Linux. Native macOS and Windows execution are
not verified; the installers have mock-test coverage. Agent hook installation is
supported on Linux, WSL, and macOS, not native Windows. The notification in the
demo is a demonstration event, not a completed live agent task.

I'd like feedback from 3–5 first-time users, especially on installation problems
and confusing shortcuts. [First-run feedback](https://github.com/gamjagoon/earlgrey.nvim/issues/new?template=first-run.yml) is welcome.

## 게시 순서와 채널

1. 아래 Reddit 스레드가 여전히 공유하기 적절한지 확인하고, 링크와 스크린샷을
   최상위 댓글로 공유합니다. 게시 전에는 당일 규칙을 다시 확인합니다.
2. 첫 사용자들의 설치 보고를 받고 재현되는 문제를 수정합니다.
3. 한국어 커뮤니티에는 당시의 게시판·홍보 규칙을 확인한 뒤 한국어 초안을 사용합니다.
4. awesome-neovim 등재 제안에는 아래 문구를 사용합니다. 공개 라이선스와 미디어를
   확인하고, 상대 저장소의 템플릿과 README 검사를 따른 뒤 제출합니다.

[r/neovim Monthly Dotfile Review](https://www.reddit.com/r/neovim/comments/1x68b1l/monthly_dotfile_review_thread/)
는 설정 링크와 가능하면 스크린샷을 올려 피드백을 받는 곳입니다.

Dotfyle 기존 후보 주소:
<https://dotfyle.com/gamjagoon/earlgreynvim-nvim>.
이번 조회에서는 본문을 검증하지 못했으므로 플러그인 수나 갱신 상태는 단정하지 않습니다.
중복 등록 전 브라우저에서 기존 페이지를 확인하세요.

## awesome-neovim 등재 제안용 문구

대상: [Pre-made Configuration](https://github.com/rockerBOO/awesome-neovim#pre-made-configuration)

PR 제목:

```text
Add `gamjagoon/earlgrey.nvim`
```

추가할 항목:

```markdown
- [gamjagoon/earlgrey.nvim](https://github.com/gamjagoon/earlgrey.nvim) - A focused configuration with terminal agent notifications, per-language LSP controls, and cross-platform installers.
```

이 프로젝트는 플러그인이 아닌 개인 설정입니다. 플러그인용 체크 항목을 그대로
단정하지 않고 기존 설정 카테고리에 추가하는 요청이라고 설명합니다. 라이선스 공개는
요건 하나를 충족하지만 등재 여부는 관리자가 판단합니다. [등재 PR #2571](https://github.com/rockerBOO/awesome-neovim/pull/2571)을 제출했으며, 병합 전에는 목록 등록이 완료된 것으로 소개하지 않습니다.

## 첫 일주일에 확인할 것

스타 수보다 처음 설치하는 사람이 실제 사용을 시작할 수 있는지 확인합니다.

- 목표: 첫 사용 피드백 3~5건. 현재 달성한 결과로 취급하지 않습니다.
- 받을 정보: OS, Neovim 버전, 실행한 설치 모드, 결과, 헷갈리는 조작.
- 문제 보고에는 재현 절차와 관련 로그의 짧은 발췌만 요청합니다. 비밀정보나 개인 경로는 필요 없습니다.
- 같은 문제가 반복되면 README의 시작 안내나 설치기를 우선 수정합니다.

## 확인 자료

2026-10-25에 프로젝트 문서·설정과 아래 자료를 확인했습니다.

- [Reddit 스레드](https://www.reddit.com/r/neovim/comments/1x68b1l/monthly_dotfile_review_thread/)
- [awesome-neovim contribution guidelines](https://github.com/rockerBOO/awesome-neovim/blob/main/CONTRIBUTING.md)
- [awesome-neovim maintainer guide](https://github.com/rockerBOO/awesome-neovim/blob/main/MAINTAINERS.md)
- [awesome-neovim PR template](https://github.com/rockerBOO/awesome-neovim/blob/main/.github/pull_request_template.md)

공개 자료 준비와 실제 커뮤니티 게시·등재 승인·사용자 확보는 구분합니다.
외부 커뮤니티에 게시하거나 첫 사용자를 확보한 상태는 아닙니다.

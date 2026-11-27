# Zed Git Graph Tasks

Zed の Git Graph の右クリックメニュー（Custom Commands）に、VS Code の Git Graph 拡張のような
checkout / ブランチ作成 / merge / rebase / cherry-pick / revert / push の操作を追加するタスク集。
Zed のグローバル `tasks.json` に差し込むインストーラ付き。

## 追加されるメニュー

ブランチやタグのラベルを右クリックした場合はその ref が、コミット行を右クリックした場合はそのコミットが対象になる。
「…」の付いた項目は、選んだ後にタスクのターミナルで方法を番号で選ぶ。

| メニュー | 選べる方法 / 動き | 出る場所 |
| --- | --- | --- |
| Checkout… | ラベルから: ① ブランチに切り替える（リモートブランチなら追跡するローカルブランチを作る。既にあればそれに切り替える） ② そのコミットを detached HEAD<br>コミット行・タグから: detached HEAD でチェックアウト（y/N） | 両方 |
| Create branch at `<sha>`… | ブランチ名を入力 → チェックアウトもするか y/N | 両方 |
| Merge into current branch… | ① 通常 ② `--no-ff` ③ `--squash`（コミットはしない） | 両方 |
| Rebase current branch onto this… | ① 通常 ② `-i`（interactive） | 両方 |
| Cherry-pick `<sha>` onto current branch… | ① 通常 ② `-x`（元のコミットを記録） ③ `--no-commit`（コミットはしない） | 両方 |
| Revert `<sha>` | `git revert --no-edit`（y/N） | 両方 |
| Push `<ref>`… | push 先のリモートを選ぶ（リモートが 1 つなら聞かない）<br>→ ① 通常 ② `--force-with-lease --force-if-includes` ③ `--force`<br>→ upstream を付けるか y/N（既定は付けない） | ラベルだけ |
| Continue (merge / rebase / cherry-pick / revert) | 途中で止まっている操作を見分けて `--continue`（エディタは開かない。確認なし） | どこでも |
| Abort (merge / rebase / cherry-pick / revert) | 途中で止まっている操作を見分けて `--abort`（y/N） | どこでも |

- 番号を選ぶことを実行の確認とみなす。空のまま Enter か `q` でキャンセルする。force-with-lease / force を選んだときだけ、さらに `yes` の入力を求める
- 実行するとタスクのターミナルに、リポジトリ・現在のブランチ・対象・コマンドを表示する。コンフリクトで止まったときは次にやることを表示する
- push は、リモートが複数あれば最初に push 先を選ぶ。選択肢には各リモートの URL を表示し、Git の既定の push 先（`branch.<ブランチ>.pushRemote` → `remote.pushDefault` → `branch.<ブランチ>.remote` → `origin` の順に決まる）を 1 番目に置いて「(既定)」と付ける。残りは名前順。Enter だけならキャンセル
- [fzf](https://github.com/junegunn/fzf) が入っていれば、push 先のリモートは fzf で名前や URL を入力して絞り込んで選ぶ。Enter でカーソルのある行を選び（最初は既定のリモート）、Esc / Ctrl-C か、該当なしのままの Enter でキャンセルする。fzf が無いか使えないときは番号で選ぶ。方法の選択（通常 / force など）は常に番号で選ぶ
- push は、選んだリモートとの差（何コミット先行 / 遅れか）と現在の upstream も表示する。方法を選んだ後、「upstream を <リモート>/<ブランチ> に設定しますか? [y/N]」と聞く（y なら `-u` を付ける）。すでに同じ upstream が設定されていれば、付けても変わらないので聞かない。ローカルブランチ以外のラベルでは実行しない。チェックアウトしていないブランチも push できる。push 先のブランチ名はローカルと同じ
- cherry-pick / revert でマージコミットを選んだ場合は、第 1 親を基準にする（`-m 1`）
- `--squash` / `--no-commit` の後は、Git Panel からコミットするよう案内を出す。読めるよう、Enter を押すまで閉じない
- Continue は、未解決のコンフリクトが残っていれば実行せずに止まる。マージは Git Panel からコミットしても完了できる

## 必要なもの

macOS / Linux の場合。Windows は [Windows](#windows) を参照。

- Zed（Git Graph の Custom Commands に対応した版）
- bash, awk, sed, diff（macOS / Linux に標準で入っている）
- jq（`jq --version` で確認。無ければ `brew install jq` や `apt install jq` で入れる）
- Git 2.30 以降（`--force-if-includes` を使うため）
- fzf（任意。入っていれば push 先のリモートを絞り込んで選べる。Zed のタスクから見える `PATH` にある必要がある）

## インストール / アンインストール

Zed を動かしているマシンで実行する。

```sh
./install.sh --dry-run   # 変更内容を確認する(書き換えない)
./install.sh             # 追加する。再実行すると最新の内容に更新する
./install.sh --lang ja   # 表示を日本語にして追加する(既定は英語)
./uninstall.sh           # 取り除く(バックアップは残す)
./uninstall.sh --purge   # バックアップも含めて削除する
```

Zed は `tasks.json` の変更を監視しているので、通常は再起動しなくても反映される。

### SSH 接続先で使う

Zed の SSH リモート開発では、タスクの定義はローカル（Zed を動かしているマシン）の `tasks.json` から読まれるが、実行は接続先で行われる。そのため接続先にも `zgt-run` を置く。

```sh
./install.sh --remote devbox             # devbox に zgt-run と messages.sh を置く(接続先ごとに 1 回)
./install.sh --remote devbox --dry-run   # 何をするかだけ表示する
./uninstall.sh --remote devbox           # devbox から取り除く
```

- Zed を動かしているマシンで実行する。`devbox` は `ssh devbox` で接続できる名前（`~/.ssh/config` のホスト名など）。接続先にこのリポジトリを clone する必要はない
- 接続先の `~/.local/share/zed-git-graph-tasks/` に置く。接続先に必要なのは bash と git だけ（無ければ注意を表示する）。fzf は任意
- 表示の言語は `--lang` で選ぶ。指定しなければローカルで選んだ言語
- このリポジトリを更新したら、ローカルと一緒に接続先も `--remote` で入れ直す。`tasks.json` が求める版より接続先の `zgt-run` が古いと、タスクの実行時に更新するよう表示する
- 接続先に `zgt-run` が無いままタスクを選ぶと、「このホストには zgt-run がありません」と入れ方を表示する
- `tasks.json` のタスクは `"command": "sh -c '<起動スクリプト>'"` の形にしてある。起動スクリプト（`lib/launcher.sh`。Windows 版と共通）は、タスクを実行したマシンの `$HOME/.local/share/zed-git-graph-tasks/zgt-run` を探して起動する
- Zed はタスクの command と args を引用符で囲まずに空白でつなぎ、利用者のシェル（SSH 接続先では接続先のシェル）に `-i -c` で渡す（Zed の `prepare_task_for_spawn`）。そのため command は `sh -c '...'` の 1 語だけにし、`${ZED_GIT_SHA}` などの値は `env` の `ZGT_ARG1`、`ZGT_ARG2`… で渡して、起動スクリプトの中で `"$ZGT_ARG1"` として `zgt-run` に渡している。利用者のシェルが zsh でも bash でも同じように動き（テストでは zsh / bash / dash で確認）、ref 名に含まれる `;` や `$(...)`（git はこれらを ref 名に使える）がシェルに実行されることもない
- `--remote` が使う ssh コマンドは環境変数 `ZGT_SSH` で変えられる（主にテスト用）
- Windows の Zed から SSH 接続した場合も同じように動く。接続先への配置は Git Bash から `./install.sh --remote <接続先>` を実行する（Git for Windows に ssh と tar が入っている）。Windows で選んだ言語は引き継がないので、日本語にするなら `--lang ja` を付ける。接続先の git は 2.31 以上が必要（[Windows](#windows) の「macOS / Linux 版との違い」を参照）

### 表示の言語

- `--lang en`（英語）か `--lang ja`（日本語）で選ぶ。`--lang=ja` の形でもよい
- 指定しなかった場合は、前回選んだ言語を引き継ぐ。初回は英語
- 切り替えたいときは `./install.sh --lang en` のように実行し直す
- 対象は、`zgt-run` の表示（確認・選択肢・結果）、install / uninstall の表示、`tasks.json` に入る目印コメントの説明文。メニュー名はどちらの言語でも英語のまま
- 文言は `lang/en.sh` / `lang/ja.sh` にある。インストール時に選んだ言語のファイルを `messages.sh` として `zgt-run` の隣に置き、`zgt-run` はそれを読み込む

### 変更されるもの

- `<設定ディレクトリ>/tasks.json` の先頭に管理ブロックを差し込む。ブロック外の既存タスクやコメントには触れない

  ```jsonc
  [
    // >>> zed-git-graph-tasks (install.sh が管理。このブロック内は編集しないでください)
    { "label": "Checkout…", ... },
    // <<< zed-git-graph-tasks
    { "label": "既存のタスク", ... },
  ]
  ```

  `tasks.json` が無ければ新しく作る。その場合、アンインストール時にほかの内容が無ければファイルごと消す
- `~/.local/share/zed-git-graph-tasks/` に次のものを置く（SSH 接続先と同じ場所）
  - `zgt-run`: 確認付きの実行ラッパー
  - `messages.sh`: 選んだ言語の文言（`lang/<言語>.sh` のコピー）
- `<設定ディレクトリ>/zed-git-graph-tasks/` に次のものを置く
  - `state`: インストール時の状態（`tasks.json` を新しく作ったか、選んだ言語）
  - `backups/`: 書き換えのたびに、直前の `tasks.json` を保存する
- 以前の版は `zgt-run` / `messages.sh` も `<設定ディレクトリ>/zed-git-graph-tasks/` に置いていた。再インストールすると新しい場所に移す
- 設定ディレクトリは macOS なら `~/.config/zed`、Linux なら `${XDG_CONFIG_HOME:-~/.config}/zed`。Flatpak 版などで場所が違う場合は `ZED_CONFIG_DIR=<パス> ./install.sh` のように指定する
- 書き込む前に結果を検証する。読めない `tasks.json` やマーカーが壊れている場合は何も変更せずに止まる

## Windows

`install.ps1` / `uninstall.ps1` を使う。タスクは Git for Windows の git と bash で `zgt-run` を動かすので、メニューの動きは macOS / Linux と同じ。

### 必要なもの

- Zed（Windows 版。Git Graph の Custom Commands に対応した版）
- [Git for Windows](https://git-scm.com/install/windows)（Git 2.31 以降）。`git` が `PATH` にあること（インストーラーの既定のまま入れればよい）。`winget install --id Git.Git -e` でも入る。`install.ps1` が確認し、無い・古い場合は止まる
- Windows PowerShell 5.1（Windows に標準で入っている）か PowerShell 7
- jq は要らない
- fzf（任意。`winget install fzf` などで入れる。Zed のタスクから見える `PATH` にある必要がある）

### インストール / アンインストール

PowerShell でこのディレクトリに移動して実行する。

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun    # 変更内容を確認する(書き換えない)
powershell -ExecutionPolicy Bypass -File .\install.ps1            # 追加する。再実行すると最新の内容に更新する
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Lang ja   # 表示を日本語にして追加する(既定は英語)
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1          # 取り除く(バックアップは残す)
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1 -Purge   # バックアップも含めて削除する
```

- `-ExecutionPolicy Bypass` はその実行にだけ効く。Windows の既定の実行ポリシー（Restricted）のままでも、設定を変えずに実行できる。PowerShell 7 なら `powershell` を `pwsh` に替えてもよい
- `-Help` で使い方を表示する
- 言語の選び方（`-Lang` を付けなければ前回の言語を引き継ぐ）は macOS / Linux 版と同じ

### macOS / Linux 版との違い

- 設定ディレクトリは `%APPDATA%\Zed`（Zed の `paths::config_dir()` と同じ）。`--user-data-dir` を付けて Zed を起動しているなど場所が違う場合は、`$env:ZED_CONFIG_DIR = '<パス>'` を設定してから実行する
- タスクの `command` は `git zgt-run` だけにし、起動スクリプト（`lib/launcher.sh`）は `env` の `GIT_CONFIG_COUNT` / `GIT_CONFIG_KEY_0` / `GIT_CONFIG_VALUE_0` で git のエイリアス `zgt-run` として渡す。git（2.31 以降）はこの環境変数を設定として読み、`!` で始まるエイリアスを Git for Windows 同梱の sh で実行する。起動スクリプトは `/usr/bin`（Git の `usr\bin`）を `PATH` の先頭に足し、同じ Git の bash で `zgt-run` を実行する

  ```jsonc
  {
    "label": "Checkout…",
    "command": "git zgt-run",
    "env": {
      "ZGT_ARG1": "${ZED_GIT_SHA}",
      "ZGT_ARG2": "${ZED_GIT_REF:@}",
      "GIT_CONFIG_COUNT": "1",
      "GIT_CONFIG_KEY_0": "alias.zgt-run",
      "GIT_CONFIG_VALUE_0": "!r=$ZGT_RUNNER; ... exec bash \"$r\" checkout \"$ZGT_ARG1\" \"$ZGT_ARG2\"; ...",
      "ZGT_RUNNER": "C:/Users/<ユーザー>/AppData/Roaming/Zed/zed-git-graph-tasks/zgt-run"
    },
    ...
  }
  ```

- こうしているのは、Windows の Zed がタスクを次のように起動するため。`command` に `C:\Program Files\Git\bin\bash.exe` のようなパスや引用符、ref の値を書くと、どこかで分かれたり解釈されたりする
  - command と args を引用符なしで空白でつなぎ、PowerShell（見つからなければ cmd）に `-C` で渡す（Zed の `prepare_task_for_spawn`）。PowerShell と cmd では引用符や記号の扱いが違い、`${ZED_GIT_REF:@}` の既定値 `@` も PowerShell では特別な記号になる
  - Zed のターミナル（alacritty）は、起動するプログラムのパスを引用符なしで Windows のコマンドラインに書く（`tty/windows` の `cmdline`）。タスクの `shell` に `bash.exe` を指定しても、パスに空白があると分かれてしまう
  - `git zgt-run` なら PowerShell でも cmd でも同じ意味になり、値やパスはどのシェルも解釈しない `env` で渡る
- `zgt-run` と `messages.sh` は `%APPDATA%\Zed\zed-git-graph-tasks\` に置き、`env` の `ZGT_RUNNER` で場所を渡す。SSH 接続先では `ZGT_RUNNER` のパスが無いので、起動スクリプトは接続先の `~/.local/share/zed-git-graph-tasks/zgt-run` を使う。そのため Windows の Zed から SSH で接続したプロジェクトでも動く（接続先に `zgt-run` を置き、git 2.31 以上があること。[SSH 接続先で使う](#ssh-接続先で使う) を参照）
- `zgt-run` と `messages.sh` は改行を LF にして置く。Windows で clone すると `core.autocrlf` で CRLF になることがあり、bash が `$'\r': command not found` で止まるため。リポジトリ側も `.gitattributes` で LF に固定している
- `tasks.json` の改行コード（CRLF / LF）と BOM の有無は元のまま保つ
- `-DryRun` の差分は `git diff --no-index` で表示する
- 管理ブロックの目印は macOS / Linux 版と同じ。目印の後ろの説明文だけ「install.ps1 が管理」になる
- 以前の版は `command` に Git Bash の `bash.exe` のパスを書き、`-Bash` オプションで場所を指定できた。今の版では bash.exe のパスを使わないので、`-Bash` は無くなった。`install.ps1` を実行し直せば新しい形に置き換わる

## タスクを追加・変更する

`tasks.d/` の断片ファイル（JSON 配列）を編集・追加してから、`./install.sh`（Windows では `install.ps1`）を再実行する。
断片ファイルはファイル名順に結合され、その順でメニューに並ぶ。`./build.sh` を実行すると結合結果を確認できる。

```json
[
  {
    "label": "Fetch origin",
    "command": "__ZGT_RUN__",
    "args": ["--confirm", "--", "git", "fetch", "--prune", "origin"],
    "hide": "on_success",
    "tags": ["git-command"]
  }
]
```

- `"tags": ["git-command"]` が無いと Git Graph のメニューに出ない
- `"command": "__ZGT_RUN__"` は、インストール時に `zgt-run` を起動する形に置き換わり、`args` は無くなる（macOS / Linux では `"command": "sh -c '<起動スクリプト>'"`、Windows では `"command": "git zgt-run"`）
  - `args` のうち記号を含まない語（サブコマンド名、`--confirm`、`git` など）は起動スクリプトにそのまま入る。それ以外（`${ZED_...}` や空白・記号を含む引数）は `env` の `ZGT_ARG<n>` で渡す（[SSH 接続先で使う](#ssh-接続先で使う) の仕組みを参照）。そのため断片ファイルの `env` には `ZGT_` と `GIT_CONFIG_` で始まる名前を使えない
- 組み込みの操作や引数を変えて、古い `zgt-run` では動かなくなる場合は、`bin/zgt-run` の `ZGT_PROTOCOL` を 1 つ上げる。SSH 接続先の `zgt-run` が古いままだと、実行時に更新するよう表示される
- 変数は必ず `${ZED_GIT_REF}` のように `{}` で囲む。Zed の変数展開は日本語の文字も変数名の一部とみなすので、`$ZED_GIT_REFを` と書くと展開に失敗し、メニューに出なくなる
- 使える変数は `ZED_GIT_SHA` / `ZED_GIT_SHA_SHORT` / `ZED_GIT_REPOSITORY_NAME` / `ZED_GIT_REPOSITORY_PATH` / `ZED_GIT_REF`（[Zed Docs: Custom Git Commands](https://zed.dev/docs/tasks#custom-git-commands)）
- `${ZED_GIT_REF}` を使うタスクは、ラベルを右クリックしたときだけ出る（コミット行には ref が無いため）。コミット行にも出したいときは、`${ZED_GIT_REF:@}` のように既定値を付ける。この書き方だと、コミット行から開いたときは `@` になる。`@` はブランチ名に使えない文字なので、本物の ref と区別できる。`zgt-run` の組み込みの操作は `@` を「ref なし」として扱う

### zgt-run の使い方

任意のコマンドを確認付きで実行する:

```
zgt-run [--confirm | --danger] [--message <文>] [--note <文>] [--require <操作>] -- <コマンド> [引数...]
```

- `--confirm`: y/N で確認する
- `--danger`: `yes` と入力しないと実行しない
- `--message <文>`: 確認の前に表示する説明
- `--note <文>`: 成功したときに表示する補足
- `--require merge|rebase|cherry-pick|revert`: その操作が途中で止まっていなければ何もしない

組み込みの操作（`tasks.d` の既存タスクが使っている。`<ref|@>` には `${ZED_GIT_REF:@}` を渡す）:

| 操作 | 内容 |
| --- | --- |
| `checkout <sha> <ref\|@>` | ref があればブランチか detached HEAD かを選ぶ。無ければ detached HEAD |
| `create-branch <sha>` | ブランチ名を入力してブランチを作る（チェックアウトするかも聞く） |
| `merge <sha> <ref\|@>` | ref（無ければコミット）をマージする。方法を選ぶ |
| `rebase <sha> <ref\|@>` | ref（無ければコミット）の上にリベースする。方法を選ぶ |
| `cherry-pick <sha> [オプション]` | cherry-pick する。オプションを渡さなければ方法を選ぶ |
| `revert <sha> [オプション]` | revert する（y/N） |
| `push <branch> [remote]` | ローカルブランチを push する。remote を省くとリモートを選ぶ（1 つなら聞かない）。方法と upstream の有無も選ぶ |
| `continue` / `abort` | 途中で止まっている merge / rebase / cherry-pick / revert を続行 / 中止する |

## 注意

- プロジェクトごとの `.zed/tasks.json` には対応していない。Zed が Git Graph 用のタスクをグローバルの `tasks.json` からしか読まないため
- 選択肢や確認はタスクのターミナルで入力する。Zed はタスクを実行するとそのターミナルにフォーカスを移す（`reveal` の既定値）ので、そのまま入力できる

## テスト

```sh
./test/run.sh
```

一時ディレクトリだけを使うので、実際の Zed の設定や Git の設定には触れない。

タスクは Zed と同じ呼び出し方で実行する。command と args を引用符なしでつないでシェル（既定は zsh。bash / dash / sh でも確認する）の `-i -c` に渡し、SSH 接続先の場合は `cd … && exec env K=V … <シェル> -i -c '…'` を偽の ssh に渡す。

`install.ps1` / `uninstall.ps1` そのものは動かしていない（Windows で確認する）。`test/run.sh` では次のことを確認する。

- Windows 版と同じ形のタスク（`git zgt-run` と `env` の git エイリアス）を jq で作り、Linux 上で同じ呼び出し方で実行する。空白を含むパスの `zgt-run`、記号を含む ref 名、SSH 接続先で `~/.local/share` に切り替わることを含む
- Windows 版が同じ取り決め（`lib/launcher.sh`、`@ARGS@`、エイリアス名、記号を含まない語の範囲）を使っていること
- PowerShell スクリプトが使う文言のキーが言語ファイルにあること
- スクリプトが ASCII だけで書かれていること（Windows PowerShell 5.1 は BOM の無いスクリプトを ANSI として読むため）

## 構成

```
install.sh / uninstall.sh   インストール / アンインストール
install.ps1 / uninstall.ps1 Windows 用のインストール / アンインストール (PowerShell)
build.sh                    tasks.d/*.json を結合する
tasks.d/                    タスクの断片ファイル
bin/zgt-run                 確認付きの実行ラッパー
lang/en.sh / lang/ja.sh     表示の文言 (キーと %s / %d の数・順番を揃える。テストで検査)
lib/common.sh               共通処理 (tasks.json の解析と差し込み)
lib/launcher.sh             tasks.json から zgt-run を起動するスクリプトのひな形 (macOS / Linux / Windows 共通)
lib/common.ps1              Windows 用の共通処理 (common.sh と build.sh の処理を PowerShell に移したもの)
test/run.sh                 テスト
.gitattributes              bash が読むファイルの改行を LF に固定する
```

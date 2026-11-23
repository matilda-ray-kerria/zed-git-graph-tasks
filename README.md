# Zed Git Graph Tasks

Zed の Git Graph の右クリックメニュー（Custom Commands）に、VS Code の Git Graph 拡張のような
push / merge / rebase の操作を追加するタスク集。Zed のグローバル `tasks.json` に差し込むインストーラ付き。

## 追加されるメニュー

`<ref>` は右クリックしたラベルのブランチ名。

| メニュー | 実行内容 | 確認 |
| --- | --- | --- |
| Push `<ref>` → origin | `git push -u origin refs/heads/<ref>:refs/heads/<ref>` | y/N |
| Push `<ref>` → origin (force-with-lease) | 上記に `--force-with-lease --force-if-includes` | `yes` と入力 |
| Push `<ref>` → origin (force) | 上記に `--force` | `yes` と入力 |
| Merge `<ref>` into current branch | `git merge --no-edit <ref>` | y/N |
| Merge `<ref>` into current branch (--no-ff) | `git merge --no-ff --no-edit <ref>` | y/N |
| Merge `<ref>` into current branch (--squash) | `git merge --squash <ref>`（コミットはしない） | y/N |
| Rebase current branch on `<ref>` | `git rebase <ref>` | y/N |
| Rebase current branch on `<ref>` (interactive) | `git rebase -i <ref>` | y/N |
| Merge: abort | `git merge --abort` | y/N |
| Rebase: continue | `git rebase --continue`（エディタを開かない） | なし |
| Rebase: abort | `git rebase --abort` | y/N |

- `<ref>` を使う項目は、ブランチ・タグのラベルを右クリックしたときだけ出る。abort / continue はどこを右クリックしても出る（マージ / リベースの途中でなければ何もしない）
- push はローカルブランチのラベルでだけ動く。チェックアウトしていないブランチも push できる。リモートブランチやタグのラベルではエラーで止まる
- 実行するとタスクのターミナルにリポジトリ・現在のブランチ・コマンドを表示してから確認する。コンフリクトで止まったときは次にやることを表示する

## 必要なもの

- Zed（Git Graph の Custom Commands に対応した版）
- bash, awk, sed, diff（macOS / Linux に標準で入っている）
- jq（`jq --version` で確認。無ければ `brew install jq` や `apt install jq` で入れる）
- Git 2.30 以降（`--force-if-includes` を使うため）

## インストール / アンインストール

Zed を動かしているマシンで実行する。

```sh
./install.sh --dry-run   # 変更内容を確認する(書き換えない)
./install.sh             # 追加する。再実行すると最新の内容に更新する
./uninstall.sh           # 取り除く(バックアップは残す)
./uninstall.sh --purge   # バックアップも含めて削除する
```

Zed は `tasks.json` の変更を監視しているので、通常は再起動しなくても反映される。

### 変更されるもの

- `<設定ディレクトリ>/tasks.json` の先頭に管理ブロックを差し込む。ブロック外の既存タスクやコメントには触れない

  ```jsonc
  [
    // >>> zed-git-graph-tasks (install.sh が管理。このブロック内は編集しないでください)
    { "label": "Push ${ZED_GIT_REF} → origin", ... },
    // <<< zed-git-graph-tasks
    { "label": "既存のタスク", ... },
  ]
  ```

  `tasks.json` が無ければ新しく作る。その場合、アンインストール時にほかの内容が無ければファイルごと消す
- `<設定ディレクトリ>/zed-git-graph-tasks/` に次のものを置く
  - `zgt-run`: 確認付きの実行ラッパー
  - `state`: インストール時の状態
  - `backups/`: 書き換えのたびに、直前の `tasks.json` を保存する
- 設定ディレクトリは macOS なら `~/.config/zed`、Linux なら `${XDG_CONFIG_HOME:-~/.config}/zed`。Flatpak 版などで場所が違う場合は `ZED_CONFIG_DIR=<パス> ./install.sh` のように指定する
- 書き込む前に結果を検証する。読めない `tasks.json` やマーカーが壊れている場合は何も変更せずに止まる

## タスクを追加・変更する

`tasks.d/` の断片ファイル（JSON 配列）を編集・追加してから、`./install.sh` を再実行する。
断片ファイルはファイル名順に結合される。`./build.sh` を実行すると結合結果を確認できる。

```json
[
  {
    "label": "Check out ${ZED_GIT_REF}",
    "command": "__ZGT_RUN__",
    "args": ["--confirm", "--", "git", "checkout", "${ZED_GIT_REF}"],
    "hide": "on_success",
    "tags": ["git-command"]
  }
]
```

- `"tags": ["git-command"]` が無いと Git Graph のメニューに出ない
- `"command": "__ZGT_RUN__"` は、インストール時に `zgt-run` のパスに置き換わる。`zgt-run` のオプションは次のとおり
  - `--confirm`: y/N で確認する
  - `--danger`: `yes` と入力しないと実行しない
  - `--message <文>`: 確認の前に表示する説明
  - `--note <文>`: 成功したときに表示する補足
  - `--require merge|rebase`: マージ / リベースの途中でなければ何もしない
- 変数は必ず `${ZED_GIT_REF}` のように `{}` で囲む。Zed の変数展開は日本語の文字も変数名の一部とみなすので、`$ZED_GIT_REFを` と書くと展開に失敗し、メニューに出なくなる
- 使える変数は `ZED_GIT_SHA` / `ZED_GIT_SHA_SHORT` / `ZED_GIT_REPOSITORY_NAME` / `ZED_GIT_REPOSITORY_PATH` / `ZED_GIT_REF`（[Zed Docs: Custom Git Commands](https://zed.dev/docs/tasks#custom-git-commands)）

## 注意

- push 先は `origin` で固定している。変えたい場合は `tasks.d/10-push.json` を編集する
- プロジェクトごとの `.zed/tasks.json` には対応していない。Zed が Git Graph 用のタスクをグローバルの `tasks.json` からしか読まないため
- 確認プロンプトはタスクのターミナルで入力を受け付ける。Zed はタスクを実行するとそのターミナルにフォーカスを移す（`reveal` の既定値）ので、そのまま入力できる

## テスト

```sh
./test/run.sh
```

一時ディレクトリだけを使うので、実際の Zed の設定や Git の設定には触れない。

## 構成

```
install.sh / uninstall.sh   インストール / アンインストール
build.sh                    tasks.d/*.json を結合する
tasks.d/                    タスクの断片ファイル
bin/zgt-run                 確認付きの実行ラッパー
lib/common.sh               共通処理 (tasks.json の解析と差し込み)
test/run.sh                 テスト
```

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
| Push `<ref>` → origin… | ① 通常 ② `--force-with-lease --force-if-includes` ③ `--force`<br>→ upstream を付けるか y/N（既定は付けない） | ラベルだけ |
| Continue (merge / rebase / cherry-pick / revert) | 途中で止まっている操作を見分けて `--continue`（エディタは開かない。確認なし） | どこでも |
| Abort (merge / rebase / cherry-pick / revert) | 途中で止まっている操作を見分けて `--abort`（y/N） | どこでも |

- 番号を選ぶことを実行の確認とみなす。空のまま Enter か `q` でキャンセルする。force-with-lease / force を選んだときだけ、さらに `yes` の入力を求める
- 実行するとタスクのターミナルに、リポジトリ・現在のブランチ・対象・コマンドを表示する。コンフリクトで止まったときは次にやることを表示する
- push は、push 先との差（何コミット先行 / 遅れか）と現在の upstream も表示する。方法を選んだ後、「upstream を origin/<ブランチ> に設定しますか? [y/N]」と聞く（y なら `-u` を付ける）。すでに同じ upstream が設定されていれば、付けても変わらないので聞かない。ローカルブランチ以外のラベルでは実行しない。チェックアウトしていないブランチも push できる
- cherry-pick / revert でマージコミットを選んだ場合は、第 1 親を基準にする（`-m 1`）
- `--squash` / `--no-commit` の後は、Git Panel からコミットするよう案内を出す。読めるよう、Enter を押すまで閉じない
- Continue は、未解決のコンフリクトが残っていれば実行せずに止まる。マージは Git Panel からコミットしても完了できる

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
    { "label": "Checkout…", ... },
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
- `"command": "__ZGT_RUN__"` は、インストール時に `zgt-run` のパスに置き換わる
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
| `push <branch> [remote]` | ローカルブランチを push する。方法と upstream の有無を選ぶ（remote の既定は origin） |
| `continue` / `abort` | 途中で止まっている merge / rebase / cherry-pick / revert を続行 / 中止する |

## 注意

- push 先は `origin` で固定している。変えたい場合は `tasks.d/60-push.json` の `"origin"` を書き換える
- プロジェクトごとの `.zed/tasks.json` には対応していない。Zed が Git Graph 用のタスクをグローバルの `tasks.json` からしか読まないため
- 選択肢や確認はタスクのターミナルで入力する。Zed はタスクを実行するとそのターミナルにフォーカスを移す（`reveal` の既定値）ので、そのまま入力できる

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

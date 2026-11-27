# shellcheck shell=bash disable=SC2034
# 日本語のメッセージ。キーと %s / %d の数・順番は lang/en.sh と揃える (test/run.sh で検査)

MSG_LANG_NAME="日本語"

# ---- zgt-run ----
MSG_LABEL_REPO="リポジトリ     "
MSG_LABEL_BRANCH="現在のブランチ "
MSG_LABEL_TARGET="対象           "
MSG_LABEL_COMMAND="コマンド       "
MSG_LABEL_UPSTREAM="upstream       "
MSG_NONE="なし"
MSG_USAGE="使い方: %s"
MSG_NEEDS_VALUE="%s には値が必要です"
MSG_UNKNOWN_OPTION="不明なオプション: %s"
MSG_NO_COMMAND="実行するコマンドがありません"
MSG_BAD_REQUIRE="--require には merge / rebase / cherry-pick / revert のどれかを指定してください"
MSG_CANCELLED="キャンセルしました。"
MSG_NOT_REPO="Git リポジトリではありません: %s"
MSG_COMMIT_NOT_FOUND="コミットが見つかりません: %s"
MSG_REF_NOT_FOUND="見つかりません: %s"
MSG_ASK_CONFIRM="実行しますか? [y/N] "
MSG_ASK_DANGER="実行するには yes と入力してください:"
MSG_CHOOSE_PROMPT="番号を選んでください (空 / q でキャンセル): "
MSG_CHOOSE_INVALID="1〜%d の番号を入力してください。"
MSG_FZF_HINT="(入力で絞り込み / Enter で選択 / Esc でキャンセル)"
MSG_DONE="✓ 完了"
MSG_PRESS_ENTER="(Enter で閉じます)"
MSG_FAILED="✗ 失敗しました (exit %d)"
MSG_STOPPED="%s が途中で止まっています。コンフリクトを解決してステージし、Custom Commands の「Continue」を実行してください (中止は「Abort」)。"
MSG_MERGE_PANEL_HINT="マージは Git Panel からコミットしても完了できます。"
MSG_NOT_IN_PROGRESS="途中で止まっている %s はありません。"
MSG_NOTHING_IN_PROGRESS="途中で止まっている merge / rebase / cherry-pick / revert はありません。"
MSG_NOTE_STAGED="変更はステージ済みです。Git Panel からコミットしてください。"

MSG_ALREADY_CHECKED_OUT="%s は既にチェックアウトしています。"
MSG_SWITCH_TO_BRANCH="ブランチ %s に切り替える"
MSG_NO_REMOTE_FOR="リモート名を判別できません: %s"
MSG_SWITCH_TRACKING="%s を追跡しているローカルブランチ %s に切り替える"
MSG_SWITCH_EXISTING="既にあるローカルブランチ %s に切り替える (追跡先: %s)"
MSG_CREATE_TRACKING="%s を追跡するローカルブランチ %s を作って切り替える"
MSG_TAG_DETACHED="タグ %s を detached HEAD でチェックアウトします。"
MSG_REF_MISSING="ブランチ / タグが見つかりません: %s"
MSG_CHECKOUT_TITLE="チェックアウトの方法を選んでください:"
MSG_CHECKOUT_DETACHED_OPT="コミット %s を detached HEAD でチェックアウトする"
MSG_ALREADY_AT_COMMIT="既にこのコミットをチェックアウトしています。"
MSG_DETACHED_WARN="このコミットを detached HEAD でチェックアウトします。ここで作業を続けるならブランチを作ってください。"

MSG_NEW_BRANCH_PROMPT="新しいブランチ名 (空でキャンセル): "
MSG_BAD_BRANCH_NAME="ブランチ名として使えません: %s"
MSG_BRANCH_EXISTS="既にあります: %s"
MSG_ASK_CHECKOUT_TOO="チェックアウトもしますか? [y/N] "

MSG_MERGE_SELF="現在のブランチ自身はマージできません。"
MSG_MERGE_TITLE="%s を現在のブランチにマージします。方法を選んでください:"
MSG_MERGE_OPT_NORMAL="通常        git merge"
MSG_MERGE_OPT_NOFF="--no-ff     fast-forward できる場合もマージコミットを作る"
MSG_MERGE_OPT_SQUASH="--squash    変更を 1 つにまとめてステージする (コミットはしない)"

MSG_REBASE_TITLE="現在のブランチを %s の上にリベースします。方法を選んでください:"
MSG_REBASE_OPT_NORMAL="通常           git rebase"
MSG_REBASE_OPT_INTERACTIVE="interactive    git rebase -i (Git に設定したエディタでコミットを並べ替え・編集する)"

MSG_PICK_DESC="このコミットの変更を現在のブランチに取り込みます。"
MSG_REVERT_DESC="このコミットを打ち消すコミットを現在のブランチに作ります。"
MSG_MERGE_COMMIT_NOTE="マージコミットなので、第 1 親を基準にします (-m 1)。"
MSG_PICK_TITLE="取り込み方を選んでください:"
MSG_PICK_OPT_NORMAL="通常          git cherry-pick"
MSG_PICK_OPT_X="-x            元のコミットをメッセージに記録する"
MSG_PICK_OPT_NOCOMMIT="--no-commit   変更だけ取り込んでステージする (コミットはしない)"

MSG_LOCAL_UPSTREAM="%s (ローカルブランチ)"
MSG_NOT_LOCAL_BRANCH="%s はローカルブランチではないので push できません。"
MSG_NO_SUCH_REMOTE="リモート %s がありません。"
MSG_NO_REMOTES="リモートが 1 つもありません。"
MSG_PUSH_REMOTE_TITLE="push 先のリモートを選んでください:"
MSG_PUSH_REMOTE_DEFAULT="(既定)"
MSG_PUSH_TARGET_DIFF="%s → %s (%s より %s コミット先行 / %s コミット遅れ。最後の fetch 時点)"
MSG_PUSH_TARGET_NEW="%s → %s (%s にはまだありません)"
MSG_PUSH_TITLE="push の方法を選んでください:"
MSG_PUSH_OPT_NORMAL="通常                git push"
MSG_PUSH_OPT_LEASE="force-with-lease    上書きする。最後に fetch した後で他の人が push していれば中止する"
MSG_PUSH_OPT_FORCE="force               無条件に上書きする (他の人が push したコミットも消える)"
MSG_ASK_UPSTREAM="upstream を %s に設定しますか? (現在: %s) [y/N] "
MSG_LEASE_WARN="%s をローカルの %s で上書きします。最後に fetch した後で他の人が push していた場合は中止されます。"
MSG_FORCE_WARN="%s を無条件に上書きします。他の人が push したコミットも消えます。"

MSG_UNRESOLVED="未解決のコンフリクトがあります。解決してステージしてから、もう一度実行してください:"
MSG_CONTINUE_DESC="途中で止まっている %s を続行します (エディタは開かず、Git が用意したメッセージを使います)。"
MSG_ABORT_DESC="途中で止まっている %s を中止し、始める前の状態に戻します (コンフリクトの解決内容は失われます)。"

# ---- install.sh / uninstall.sh / build.sh ----
MSG_REQUIRE_CMD="'%s' が見つかりません。インストールしてから再実行してください。"
MSG_UNKNOWN_ARG="不明な引数: %s"
MSG_UNKNOWN_LANG="言語 '%s' はありません (選べるもの: %s)"
MSG_BLOCK_NOTE="(install.sh が管理。このブロック内は編集しないでください)"
MSG_NO_FRAGMENTS="tasks.d/*.json がありません"
MSG_BAD_FRAGMENT="不正な断片ファイル: %s (label と command を持つオブジェクトの配列にしてください)"
MSG_BUILD_FAILED="tasks.d の結合に失敗しました"
MSG_TASKS_UNREADABLE="%s を JSON 配列として読めませんでした。内容を確認してください (変更していません)"
MSG_NO_ARRAY_START="%s の先頭に配列の [ が見つかりませんでした (変更していません)"
MSG_BROKEN_MARKERS="%s の管理ブロックのマーカー (%s / %s) が壊れています。手で直してから再実行してください (変更していません)"
MSG_VERIFY_FAILED="生成結果の検証に失敗しました (変更していません)"
MSG_COUNT_MISMATCH="生成結果のタスク数が一致しません (期待 %s / 実際 %s)。変更していません"
MSG_DRYRUN_INSTALL="# dry-run: %s への変更 (書き換えはしていません)"
MSG_UP_TO_DATE="tasks.json は最新です (%s 個のタスク)。ラッパーを更新しました: %s"
MSG_INSTALLED="✓ %s 個のタスクを追加しました: %s"
MSG_BACKUP_AT="  バックアップ: %s"
MSG_RUNNER_AT="  ラッパー:     %s"
MSG_LANG_AT="  言語:         %s (変更するには ./install.sh --lang en|ja)"
MSG_HOW_TO_USE="Zed の Git Graph でコミット行やブランチのラベルを右クリック → Custom Commands から使えます。"
MSG_DRYRUN="# dry-run (書き換えはしていません)"
MSG_NO_BLOCK="%s に管理ブロックはありません"
MSG_STRIP_VERIFY_FAILED="ブロック削除後の内容を検証できませんでした (変更していません)"
MSG_WILL_DELETE="%s を削除します (install.sh が作成したファイルのため)"
MSG_WILL_REMOVE_RUNNER="%s の zgt-run / messages.sh / state を削除します"
MSG_WILL_PURGE="%s をバックアップごと削除します"
MSG_BLOCK_REMOVED="✓ 管理ブロックを取り除きました: %s"
MSG_DELETED="✓ %s を削除しました (install.sh が作成したファイルのため)"
MSG_PURGED="✓ %s を削除しました"
MSG_PURGE_HINT="  (バックアップを消すには ./uninstall.sh --purge)"
MSG_WILL_REMOVE_FILES="%s の zgt-run / messages.sh を削除します"

# ---- SSH 接続先 (install.sh / uninstall.sh --remote と tasks.json の起動スクリプト) ----
# MSG_RUNNER_MISSING は tasks.json の sh -c '...' の中の printf "..." に埋め込むので、' " $ ` \ と %s 以外の % を含めない
MSG_RUNNER_MISSING="このホスト (%s) には zgt-run がありません。Zed を動かしているマシンで ./install.sh --remote <SSH の接続先> を実行してください。"
MSG_RUNNER_OUTDATED="このホスト (%s) の zgt-run は古いため、このタスクを実行できません。Zed を動かしているマシンで ./install.sh --remote <SSH の接続先> を実行して更新してください。"
MSG_REMOTE_HINT="  SSH 接続先でも使うには: ./install.sh --remote <SSH の接続先> (接続先ごとに 1 回)"
MSG_REMOTE_DRYRUN="# dry-run: %s の %s に zgt-run と messages.sh (%s) を置きます (書き込みはしていません)"
MSG_REMOTE_DRYRUN_UNINSTALL="# dry-run: %s の %s から zgt-run と messages.sh を取り除きます (書き込みはしていません)"
MSG_REMOTE_INSTALLED="✓ %s に zgt-run を置きました: %s"
MSG_REMOTE_REMOVED="✓ %s から zgt-run を取り除きました"
MSG_REMOTE_FAILED="%s への接続か書き込みに失敗しました"
MSG_REMOTE_MISSING_CMD="  注意: %s に %s が見つかりません (zgt-run の実行に必要です)"

MSG_BUILD_USAGE='使い方: ./build.sh [--expand]

tasks.d/*.json を名前順に結合して標準出力に出します。
  --expand  "command": "__ZGT_RUN__" を、zgt-run を探して起動する sh -c の起動スクリプトに置き換える (install.sh が使用)

環境変数:
  ZGT_LANG  メッセージの言語 (en / ja。既定: en)'

MSG_INSTALL_USAGE='使い方: ./install.sh [--lang en|ja] [--dry-run]
        ./install.sh --remote <SSH の接続先> [--lang en|ja] [--dry-run]

tasks.d/*.json を結合し、Zed のグローバル tasks.json に管理ブロックとして追加します。
既に追加済みならブロックを最新の内容に差し替えます。既存のタスクやコメントには触れません。
zgt-run と messages.sh は ~/.local/share/zed-git-graph-tasks/ に置きます。

  --lang en|ja     表示の言語 (既定: 前回選んだ言語。初回は en)
  --remote <host>  SSH 接続先の ~/.local/share/zed-git-graph-tasks/ に zgt-run と messages.sh だけを置く
                   (Zed は SSH 接続先のプロジェクトではタスクを接続先で実行するため。接続先ごとに 1 回)
  --dry-run        書き換えずに内容だけ表示する

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
  ZGT_SSH         --remote で使う ssh コマンド (既定: ssh)'

MSG_UNINSTALL_USAGE='使い方: ./uninstall.sh [--dry-run] [--purge]
        ./uninstall.sh --remote <SSH の接続先> [--dry-run]

Zed のグローバル tasks.json から管理ブロックだけを取り除き、ラッパーを削除します。
ブロック外のタスクやコメントには触れません。

  --dry-run        書き換えずに内容だけ表示する
  --purge          バックアップも含めて設定ディレクトリ内の zed-git-graph-tasks/ を削除する
  --remote <host>  SSH 接続先の zgt-run と messages.sh だけを取り除く

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
  ZGT_SSH         --remote で使う ssh コマンド (既定: ssh)'

# ---- install.ps1 / uninstall.ps1 (Windows) ----
# lib/common.ps1 が独自に読む (bash もこのファイルを読み込む)。値は "..." か '...' で書き、
# $ や \ を含む文は単一引用符で囲む
MSG_WINDOWS_ONLY_PS="install.ps1 / uninstall.ps1 は Windows 用です。macOS / Linux では ./install.sh / ./uninstall.sh を使ってください"
MSG_NO_GIT_PS='PATH 上に git が見つかりません。タスクは "git zgt-run" として実行されるので、Git for Windows を入れ (winget install --id Git.Git -e)、git を PATH に通してから (インストーラーの既定) もう一度実行してください'
MSG_GIT_TOO_OLD_PS="PATH 上の git が古すぎます: %s (バージョン %s)。タスクの実行には git %s 以上が必要です。Git for Windows を更新してください (winget upgrade --id Git.Git -e)"
MSG_GIT_AT_PS="  git:          %s"
MSG_BLOCK_NOTE_PS="(install.ps1 が管理。このブロック内は編集しないでください)"
MSG_LANG_AT_PS='  言語:         %s (変更するには .\install.ps1 -Lang en|ja)'
MSG_WILL_DELETE_PS="%s を削除します (install.ps1 が作成したファイルのため)"
MSG_DELETED_PS="✓ %s を削除しました (install.ps1 が作成したファイルのため)"
MSG_PURGE_HINT_PS='  (バックアップを消すには .\uninstall.ps1 -Purge)'

MSG_INSTALL_USAGE_PS='使い方: .\install.ps1 [-Lang en|ja] [-DryRun]

tasks.d\*.json を結合し、Zed のグローバル tasks.json に管理ブロックとして追加します。
既に追加済みならブロックを最新の内容に差し替えます。既存のタスクやコメントには触れません。
タスクは git (PATH 上の Git for Windows 2.31 以上) を通して zgt-run を実行します。

  -Lang en|ja  表示の言語 (既定: 前回選んだ言語。初回は en)
  -DryRun      書き換えずに差分だけ表示する

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: $env:APPDATA\Zed)'

MSG_UNINSTALL_USAGE_PS='使い方: .\uninstall.ps1 [-DryRun] [-Purge]

Zed のグローバル tasks.json から管理ブロックだけを取り除き、ラッパーを削除します。
ブロック外のタスクやコメントには触れません。

  -DryRun  書き換えずに差分だけ表示する
  -Purge   バックアップも含めて設定ディレクトリ内の zed-git-graph-tasks\ を削除する

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: $env:APPDATA\Zed)'

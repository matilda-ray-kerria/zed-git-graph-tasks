#!/usr/bin/env bash
# install.sh / uninstall.sh / zgt-run のテスト。一時ディレクトリだけを使い、実際の Zed 設定には触れない。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/zgt-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export ZED_CONFIG_DIR="$WORK/zed"
# zgt-run は ~/.local/share/zed-git-graph-tasks/ に置かれるので、HOME も一時ディレクトリにする
export HOME="$WORK/home"
mkdir -p "$HOME"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main
# エディタが開かれたら失敗させる (タスクがエディタ待ちで止まらないことを確かめる)
export GIT_EDITOR=false
# ホストに fzf が入っていても使わない (fzf のテストでは偽の fzf を指定する)
export ZGT_FZF=zgt-test-no-fzf

TASKS="$ZED_CONFIG_DIR/tasks.json"
RUNNER="$HOME/.local/share/zed-git-graph-tasks/zgt-run"
. "$ROOT/lib/common.sh"

pass=0
fail=0
ok() {
  pass=$((pass + 1))
  printf '  ok   %s\n' "$1"
}
ng() {
  fail=$((fail + 1))
  printf '  FAIL %s\n' "$1"
}
check() { # check <説明> <コマンド...>
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else ng "$desc"; fi
}
count_tasks() { zgt_jsonc_to_json "$TASKS" | jq 'length'; }
# 管理ブロックのタスク (command が sh で、起動スクリプトの後に zgt-run が続くもの) の数
count_ours() {
  zgt_jsonc_to_json "$TASKS" | jq '[.[] | select(.command == "sh" and .args[0] == "-c" and .args[2] == "zgt-run")] | length'
}

# Zed の代わりに tasks.json のタスクを実行する。REF / SHA に右クリックした ref / コミットを入れておく。
# REF が空ならコミット行から開いた扱い (Zed と同じく ${ZED_GIT_REF} を使うタスクは出ない、
# ${ZED_GIT_REF:既定値} は既定値になる)
#   run_task <ラベル(テンプレート)> <標準入力に渡す内容>
REF=""
SHA=""
run_task() {
  local label="$1" input="$2" line
  local -a cmd=() envs=()
  if [ -z "$REF" ] && zgt_jsonc_to_json "$TASKS" |
    jq -e --arg l "$label" '.[] | select(.label == $l) | tostring | contains("${ZED_GIT_REF}")' >/dev/null; then
    echo "コミット行のメニューには出ないタスク: $label" >&2
    return 98
  fi
  while IFS= read -r line; do cmd+=("$line"); done < <(
    zgt_jsonc_to_json "$TASKS" | jq -r --arg l "$label" --arg ref "$REF" --arg sha "$SHA" \
      --arg short "${SHA:0:7}" '
      .[] | select(.label == $l) | ([.command] + .args)[]
      | gsub("\\$\\{ZED_GIT_REF\\}"; $ref)
      | gsub("\\$\\{ZED_GIT_REF:(?<d>[^}]*)\\}"; if $ref == "" then .d else $ref end)
      | gsub("\\$\\{ZED_GIT_SHA\\}"; $sha)
      | gsub("\\$\\{ZED_GIT_SHA_SHORT\\}"; $short)')
  while IFS= read -r line; do envs+=("$line"); done < <(
    zgt_jsonc_to_json "$TASKS" | jq -r --arg l "$label" '
      .[] | select(.label == $l) | (.env // {}) | to_entries[] | "\(.key)=\(.value)"')
  [ ${#cmd[@]} -gt 0 ] || {
    echo "task not found: $label" >&2
    return 99
  }
  printf '%s\n' "$input" | env ${envs[@]+"${envs[@]}"} "${cmd[@]}"
}
cur() { git symbolic-ref --short -q HEAD || echo DETACHED; }
subject() { git log -1 --format=%s "${1:-HEAD}"; }
count_parents() { git rev-list --parents -n 1 "${1:-HEAD}" | awk '{ print NF - 1 }'; }
commit_file() { # commit_file <ファイル> <内容> <メッセージ>
  printf '%s\n' "$2" >"$1" && git add "$1" && git commit -q -m "$3"
}

echo "== build"
check "断片ファイルを結合できる" "$ROOT/build.sh"
total="$("$ROOT/build.sh" | jq 'length')"
check "全タスクに git-command タグがある" \
  test "$("$ROOT/build.sh" | jq '[.[] | select(.tags | index("git-command"))] | length')" = "$total"
check "変数は \${...} 形式だけを使う (日本語が変数名に含まれないように)" \
  test -z "$(grep -n '\$ZED_' "$ROOT"/tasks.d/*.json)"
# Zed は未定義の ZED_ 変数を含むタスクをメニューに出さない (コミット行には ZED_GIT_REF が無い)
commit_menu="$("$ROOT/build.sh" | jq '[.[] | select(tostring | contains("${ZED_GIT_REF}") | not)] | length')"
check "コミット行のメニューに出るのは push 以外の 8 個 (全 $total 個)" test "$commit_menu" = 8 -a "$total" = 9

echo "== 新規インストール (tasks.json なし)"
"$ROOT/install.sh" >/dev/null
check "tasks.json が作られる" test -f "$TASKS"
check "Zed 形式として読める" zgt_validate_jsonc "$TASKS"
check "全タスクが入る ($total 個)" test "$(count_ours)" = "$total"
check "ラッパーが実行可能" test -x "$RUNNER"
check "tasks.json はローカルの絶対パスを含まない (SSH 接続先でも同じ定義で動くように)" \
  test -z "$(grep -F "$HOME" "$TASKS")"
check "起動スクリプトは実行したマシンの \$HOME から zgt-run を探す" \
  grep -qF '$HOME/.local/share/zed-git-graph-tasks/zgt-run' "$TASKS"
check "起動スクリプトに zgt-run の取り決めの版を埋め込む" \
  grep -qF "ZGT_REQUIRED_PROTOCOL=$(sed -n 's/^ZGT_PROTOCOL=//p' "$ROOT/bin/zgt-run")" "$TASKS"
cp "$TASKS" "$WORK/first"
"$ROOT/install.sh" >/dev/null
check "再インストールしても内容が変わらない" cmp -s "$TASKS" "$WORK/first"
"$ROOT/uninstall.sh" >/dev/null
check "自分で作った tasks.json はアンインストールで消える" test ! -e "$TASKS"
check "ラッパーが消える" test ! -e "$RUNNER"
mkdir -p "$ZED_CONFIG_DIR/zed-git-graph-tasks"
touch "$ZED_CONFIG_DIR/zed-git-graph-tasks/zgt-run" "$ZED_CONFIG_DIR/zed-git-graph-tasks/messages.sh"
"$ROOT/install.sh" >/dev/null
check "以前の版の置き場所 (Zed の設定ディレクトリ) に残ったラッパーを消す" \
  test ! -e "$ZED_CONFIG_DIR/zed-git-graph-tasks/zgt-run" -a ! -e "$ZED_CONFIG_DIR/zed-git-graph-tasks/messages.sh"
"$ROOT/uninstall.sh" --purge >/dev/null

echo "== 既存の tasks.json (コメント・末尾カンマあり)"
mkdir -p "$ZED_CONFIG_DIR"
cat >"$TASKS" <<'EOF'
// my tasks
[
  /* ブロックコメント [ { , */
  {
    "label": "hello // これはコメントではない",
    "command": "echo",
    "args": ["a,b", "]", "\"q\""], // 行末コメント
  },
]
EOF
cp "$TASKS" "$WORK/orig"
"$ROOT/install.sh" --dry-run >/dev/null
check "dry-run では書き換えない" cmp -s "$TASKS" "$WORK/orig"
"$ROOT/install.sh" >/dev/null
check "Zed 形式として読める" zgt_validate_jsonc "$TASKS"
check "既存タスク + 全タスク" test "$(count_tasks)" = "$((total + 1))"
check "既存のコメントが残る" grep -q '行末コメント' "$TASKS"
check "バックアップが取られる" test -n "$(ls "$ZED_CONFIG_DIR/zed-git-graph-tasks/backups/")"
cp "$TASKS" "$WORK/installed"
"$ROOT/install.sh" >/dev/null
check "再インストールしても内容が変わらない" cmp -s "$TASKS" "$WORK/installed"
"$ROOT/uninstall.sh" >/dev/null
check "アンインストールで元のファイルに完全に戻る" cmp -s "$TASKS" "$WORK/orig"
"$ROOT/uninstall.sh" --purge >/dev/null
check "--purge で管理ディレクトリが消える" test ! -e "$ZED_CONFIG_DIR/zed-git-graph-tasks"

echo "== 1 行で書かれた tasks.json / 空配列"
printf '[{"label":"x","command":"true"}]\n' >"$TASKS"
"$ROOT/install.sh" >/dev/null
check "1 行形式にも差し込める" test "$(count_tasks)" = "$((total + 1))"
"$ROOT/uninstall.sh" --purge >/dev/null
check "1 行形式でも読める状態に戻る" test "$(count_tasks)" = 1
printf '[]\n' >"$TASKS"
"$ROOT/install.sh" >/dev/null
check "空配列に差し込める" test "$(count_tasks)" = "$total"
"$ROOT/uninstall.sh" --purge >/dev/null
check "空配列に戻る (自分で作っていないので消さない)" test "$(zgt_jsonc_to_json "$TASKS" | jq -c .)" = "[]"

echo "== 不正なファイルには触れない"
printf '{"label": "not an array"}\n' >"$TASKS"
cp "$TASKS" "$WORK/bad"
check "トップレベルが配列でなければ失敗する" test "$("$ROOT/install.sh" >/dev/null 2>&1; echo $?)" != 0
check "ファイルは変更されない" cmp -s "$TASKS" "$WORK/bad"
printf '[\n  // >>> zed-git-graph-tasks\n]\n' >"$TASKS"
cp "$TASKS" "$WORK/bad"
check "マーカーが壊れていれば失敗する" test "$("$ROOT/install.sh" >/dev/null 2>&1; echo $?)" != 0
check "ファイルは変更されない" cmp -s "$TASKS" "$WORK/bad"
rm -f "$TASKS"

echo "== 言語"
lang_keys() { sed -n 's/^\(MSG_[A-Z0-9_]*\)=.*/\1/p' "$1" | sort; }
# 各キーの %s / %d の並び (翻訳で差し込む値の数や順番がずれていないか)
lang_placeholders() {
  (
    . "$1"
    for k in $(lang_keys "$1"); do
      printf '%s:%s\n' "$k" "$(printf '%s' "${!k}" | grep -o '%[sd]' | tr -d '\n')"
    done
  )
}
# スクリプトが使っているキー (Windows 用の .ps1 も含める)
used_keys() {
  grep -ohE '(zgt_msg|msg|say|show_field|Get-ZgtMessage|Write-ZgtMessage|Write-ZgtRaw) [A-Z][A-Z0-9_]+|MSG_[A-Z0-9_]+' \
    "$ROOT"/bin/zgt-run "$ROOT"/*.sh "$ROOT"/lib/common.sh "$ROOT"/*.ps1 "$ROOT"/lib/common.ps1 |
    sed -E 's/^(zgt_msg|msg|say|show_field|Get-ZgtMessage|Write-ZgtMessage|Write-ZgtRaw) /MSG_/' | sort -u
}
STATE="$ZED_CONFIG_DIR/zed-git-graph-tasks/state"
MESSAGES="$HOME/.local/share/zed-git-graph-tasks/messages.sh"
check "en / ja の言語ファイルのキーが一致する" \
  test "$(lang_keys "$ROOT/lang/en.sh")" = "$(lang_keys "$ROOT/lang/ja.sh")"
check "en / ja で差し込む値 (%s / %d) の数と順番が一致する" \
  test "$(lang_placeholders "$ROOT/lang/en.sh")" = "$(lang_placeholders "$ROOT/lang/ja.sh")"
check "スクリプトが使うキーはすべて言語ファイルにある" \
  test -z "$(comm -23 <(used_keys) <(lang_keys "$ROOT/lang/en.sh"))"
# Windows PowerShell 5.1 は BOM の無いスクリプトを ANSI コードページで読むため、.ps1 は ASCII だけで書く
# (.ps1 自体の動作はここではテストしない。Windows で確認する)
check "PowerShell スクリプトは ASCII だけで書かれている" \
  test -z "$(LC_ALL=C grep -l '[^[:print:][:space:]]' "$ROOT"/*.ps1 "$ROOT"/lib/*.ps1)"
out="$("$ROOT/install.sh" 2>&1)"
check "--lang を付けなければ英語でインストールする" \
  test "$(zgt_state_get "$STATE" lang)" = en -a -n "$(grep 'Added' <<<"$out")"
check "英語のメッセージをラッパーの隣に置く" cmp -s "$MESSAGES" "$ROOT/lang/en.sh"
check "tasks.json の目印コメントも英語" grep -q 'managed by install.sh' "$TASKS"
out="$("$ROOT/install.sh" --lang ja 2>&1)"
check "--lang ja で日本語に切り替わる" \
  test "$(zgt_state_get "$STATE" lang)" = ja -a -n "$(grep '追加しました' <<<"$out")"
check "日本語のメッセージに差し替わる" cmp -s "$MESSAGES" "$ROOT/lang/ja.sh"
check "tasks.json の目印コメントも日本語に差し替わる" \
  test -n "$(grep 'install.sh が管理' "$TASKS")" -a -z "$(grep 'managed by' "$TASKS")"
"$ROOT/install.sh" >/dev/null
check "再インストールでは前回の言語を引き継ぐ" cmp -s "$MESSAGES" "$ROOT/lang/ja.sh"
check "--help も選んだ言語で出る" grep -q '使い方' <<<"$("$ROOT/install.sh" --help)"
cp "$TASKS" "$WORK/before-lang"
out="$("$ROOT/install.sh" --lang xx 2>&1)"
check "無い言語を指定すると失敗し、選べる言語を示す" \
  test -n "$(grep 'available: en ja' <<<"$out")" -a "$(zgt_state_get "$STATE" lang)" = ja
check "無い言語を指定しても tasks.json は変わらない" cmp -s "$TASKS" "$WORK/before-lang"
"$ROOT/install.sh" --lang=en >/dev/null
check "--lang=en の形でも切り替えられる" cmp -s "$MESSAGES" "$ROOT/lang/en.sh"
"$ROOT/install.sh" --lang ja >/dev/null
out="$("$ROOT/uninstall.sh" 2>&1)"
check "アンインストールもインストール時の言語で表示する" grep -q '削除しました' <<<"$out"
check "アンインストールでメッセージも消える" test ! -e "$MESSAGES"

# ---- ここからタスクの実行 (Zed の代わりに tasks.json から実行する) ----
# 以降のテストは日本語の文言で確かめる
"$ROOT/install.sh" --lang ja >/dev/null
git init -q --bare "$WORK/remote.git"
git clone -q "$WORK/remote.git" "$WORK/repo" 2>/dev/null
cd "$WORK/repo" || exit 1
commit_file c.txt base base
git push -q origin main 2>/dev/null
git remote set-head origin main
git switch -q -c feature
commit_file f.txt feature feature
git switch -q main
base="$(git rev-parse main)"

CHECKOUT='Checkout…'
CREATE='Create branch at ${ZED_GIT_SHA_SHORT}…'
MERGE='Merge into current branch…'
REBASE='Rebase current branch onto this…'
PICK='Cherry-pick ${ZED_GIT_SHA_SHORT} onto current branch…'
REVERT='Revert ${ZED_GIT_SHA_SHORT}'
PUSH='Push ${ZED_GIT_REF}…'
CONTINUE='Continue (merge / rebase / cherry-pick / revert)'
ABORT='Abort (merge / rebase / cherry-pick / revert)'

echo "== 番号の選択"
REF=feature SHA="$(git rev-parse feature)"
out="$(run_task "$MERGE" $'x\n9' 2>&1)"
check "番号以外・範囲外は聞き直す" grep -q '1〜3 の番号を入力してください' <<<"$out"
check "選ばないまま入力が終われば何もしない" test "$(git rev-parse HEAD)" = "$base"
run_task "$MERGE" q >/dev/null
check "q でキャンセル" test "$(git rev-parse HEAD)" = "$base"
run_task "$MERGE" "" >/dev/null
check "空入力でキャンセルし、成功扱い (exit 0)" test $? -eq 0 -a "$(git rev-parse HEAD)" = "$base"

echo "== push"
REF=feature
out="$(REF="" run_task "$PUSH" 1 2>&1)"
check "コミット行のメニューには出ない" test $? -eq 98
run_task "$PUSH" "" >/dev/null
check "空入力ならキャンセル" test -z "$(git ls-remote origin refs/heads/feature)"
out="$(run_task "$PUSH" $'1\n' 2>&1)"
check "1 でチェックアウトしていないブランチを push できる" test -n "$(git ls-remote origin refs/heads/feature)"
check "リモートにまだ無いことを表示する" grep -q 'origin にはまだありません' <<<"$out"
check "現在の upstream (なし) を表示する" grep -q 'upstream  *なし' <<<"$out"
check "upstream: Enter なら付けない" test -z "$(git config branch.feature.merge)"
run_task "$PUSH" $'1\ny' >/dev/null 2>&1
check "upstream: y なら -u で設定する" test "$(git config branch.feature.merge)" = refs/heads/feature
out="$(run_task "$PUSH" $'1\n' 2>&1)"
check "upstream: 既に同じ upstream なら聞かない" test -z "$(grep 'upstream を' <<<"$out")"
git branch -q --track track-main origin/main
out="$(REF=track-main run_task "$PUSH" $'1\ny' 2>&1)"
check "upstream: 別の upstream なら現在の値を示して聞く" grep -q '現在: origin/main' <<<"$out"
check "upstream: y なら push 先に付け替える" test "$(git config branch.track-main.merge)" = refs/heads/track-main
git branch -q force-up "$base"
REF=force-up run_task "$PUSH" $'3\ny\nyes' >/dev/null 2>&1
check "upstream: force でも付けられる (方法 → upstream → yes の順)" \
  test -n "$(git ls-remote origin refs/heads/force-up)" -a "$(git config branch.force-up.merge)" = refs/heads/force-up
out="$(REF=origin/main run_task "$PUSH" 1 2>&1)"
check "リモートブランチのラベルでは push しない" grep -q 'ローカルブランチではない' <<<"$out"

git switch -q feature && git commit -q --amend -m "feature (amended)" && git switch -q main
out="$(run_task "$PUSH" $'2\ny' 2>&1)"
check "force-with-lease: y では実行しない (yes が必要)" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" != "$(git rev-parse feature)"
check "先行 / 遅れのコミット数を表示する" grep -q '1 コミット先行 / 1 コミット遅れ' <<<"$out"
run_task "$PUSH" $'2\nyes' >/dev/null 2>&1
check "force-with-lease: yes で上書きできる" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git rev-parse feature)"

git clone -q "$WORK/remote.git" "$WORK/other" 2>/dev/null
(cd "$WORK/other" && git switch -q feature && commit_file o.txt other other &&
  git push -q origin feature 2>/dev/null)
git switch -q feature && git commit -q --amend -m "feature (amended again)" && git switch -q main
git fetch -q origin
run_task "$PUSH" $'2\nyes' >/dev/null 2>&1
check "force-with-lease: 他人の push を fetch しただけで取り込んでいなければ拒否される" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" != "$(git rev-parse feature)"
run_task "$PUSH" $'3\nyes' >/dev/null 2>&1
check "force: yes で無条件に上書きできる" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git rev-parse feature)"
check "リモートが 1 つなら push 先を聞かない" test -z "$(grep 'push 先のリモート' <<<"$out")"

git init -q --bare "$WORK/backup.git"
git remote add backup "$WORK/backup.git"
out="$(run_task "$PUSH" "" 2>&1)"
check "リモートが複数なら push 先を選ぶ (空入力ならキャンセル)" \
  test -n "$(grep 'push 先のリモートを選んでください' <<<"$out")" -a -z "$(git ls-remote backup)"
check "既定のリモート (追跡先の origin) を先頭に印付きで並べる" grep -q '1) origin .* (既定)$' <<<"$out"
check "選択肢にリモートの URL を表示する" grep -q "2) backup  $WORK/backup.git" <<<"$out"
out="$(run_task "$PUSH" $'2\n1\n' 2>&1)"
check "2 を選ぶと backup に push する" \
  test "$(git ls-remote backup refs/heads/feature | cut -f1)" = "$(git rev-parse feature)"
check "選んだリモートとの差を表示する" grep -q 'backup にはまだありません' <<<"$out"
check "upstream は聞くだけで、Enter なら origin のまま" test "$(git config branch.feature.remote)" = origin
git config remote.pushDefault backup
out="$(run_task "$PUSH" "" 2>&1)"
check "remote.pushDefault があればそれを既定にする" grep -q '1) backup .* (既定)$' <<<"$out"
git config --unset remote.pushDefault

echo "== fzf (偽の fzf で確認)"
cat >"$WORK/fake-fzf" <<'EOF'
#!/usr/bin/env bash
# テスト用の偽 fzf: 引数と入力を記録し、FAKE_FZF_MODE / FAKE_FZF_PICK に従って結果を返す
printf '%s\n' "$@" >"$FAKE_FZF_DIR/args"
cat >"$FAKE_FZF_DIR/input"
case "${FAKE_FZF_MODE:-pick}" in
  cancel) exit 130 ;;
  nomatch) exit 1 ;;
  error) exit 2 ;;
esac
grep -F -- "$FAKE_FZF_PICK" "$FAKE_FZF_DIR/input" | head -n 1
EOF
chmod +x "$WORK/fake-fzf"
export FAKE_FZF_DIR="$WORK/fzf-log"
mkdir -p "$FAKE_FZF_DIR"
# fzf_run <モード> <選ぶ行に含まれる文字列> <標準入力>: 偽の fzf がある状態で push を実行する
fzf_run() { FAKE_FZF_MODE="$1" FAKE_FZF_PICK="$2" ZGT_FZF="$WORK/fake-fzf" run_task "$PUSH" "$3"; }
TAB="$(printf '\t')"
git branch -q fz "$base"
REF=fz
out="$(fzf_run pick backup $'1\n' 2>&1)"
check "fzf で選んだリモート (backup) に push する" \
  test -n "$(git ls-remote backup refs/heads/fz)" -a -z "$(git ls-remote origin refs/heads/fz)"
check "fzf には番号を隠して名前と URL を渡す" grep -q -- '--with-nth' "$FAKE_FZF_DIR/args"
check "fzf の一覧は既定のリモートが先頭" grep -q "^1${TAB}origin .* (既定)$" <(head -n 1 "$FAKE_FZF_DIR/input")
check "fzf の見出しに説明と操作方法を出す" grep -q 'push 先のリモートを選んでください:  (入力で絞り込み' "$FAKE_FZF_DIR/args"
check "fzf を使うときは番号の選択肢を出さない" test -z "$(grep '1) origin' <<<"$out")"
git push -q backup --delete fz 2>/dev/null
out="$(fzf_run cancel "" "" 2>&1)"
check "fzf で Esc / Ctrl-C (130) ならキャンセル" \
  test -n "$(grep 'キャンセルしました' <<<"$out")" -a -z "$(git ls-remote backup refs/heads/fz)$(git ls-remote origin refs/heads/fz)"
out="$(fzf_run nomatch "" "" 2>&1)"
check "fzf で該当なし (1) ならキャンセル" grep -q 'キャンセルしました' <<<"$out"
out="$(fzf_run error "" $'1\n1\n' 2>&1)"
check "fzf が使えなければ (2) 番号選択になる" \
  test -n "$(grep '1) origin' <<<"$out")" -a -n "$(git ls-remote origin refs/heads/fz)"
git remote remove backup
rm -f "$FAKE_FZF_DIR/args"
fzf_run pick origin $'1\n' >/dev/null 2>&1
check "リモートが 1 つなら fzf も使わない" test ! -e "$FAKE_FZF_DIR/args"

echo "== checkout"
REF=feature SHA="$(git rev-parse feature)"
run_task "$CHECKOUT" "" >/dev/null
check "空入力ならキャンセル" test "$(cur)" = main
out="$(run_task "$CHECKOUT" 1 2>&1)"
check "ブランチラベルからはブランチか detached HEAD かを選ぶ" grep -q 'detached HEAD でチェックアウトする' <<<"$out"
check "1 でブランチに切り替わる" test "$(cur)" = feature
out="$(run_task "$CHECKOUT" 1 2>&1)"
check "チェックアウト中のブランチなら何もしない" grep -q '既にチェックアウトしています' <<<"$out"
git switch -q main
run_task "$CHECKOUT" 2 >/dev/null 2>&1
check "2 でそのコミットを detached HEAD でチェックアウトする" \
  test "$(cur)" = DETACHED -a "$(git rev-parse HEAD)" = "$SHA"
git switch -q main
(cd "$WORK/other" && git switch -q -c remote-only && commit_file r.txt r remote-only &&
  git push -q origin remote-only 2>/dev/null)
git fetch -q origin
REF=origin/remote-only SHA="$(git rev-parse origin/remote-only)" run_task "$CHECKOUT" 1 >/dev/null 2>&1
check "リモートブランチなら追跡するローカルブランチを作って切り替える" test "$(cur)" = remote-only
check "作ったブランチの upstream が origin/remote-only" \
  test "$(git rev-parse --abbrev-ref 'remote-only@{upstream}')" = origin/remote-only
REF=origin/HEAD SHA="$base" run_task "$CHECKOUT" 1 >/dev/null 2>&1
check "origin/HEAD は指している先 (main) に切り替える" test "$(cur)" = main
git tag v1 "$base"
REF=v1 SHA="$base" run_task "$CHECKOUT" n >/dev/null
check "タグは y/N で確認する (n でキャンセル)" test "$(cur)" = main
REF=v1 SHA="$base" run_task "$CHECKOUT" y >/dev/null 2>&1
check "タグは detached HEAD でチェックアウトする" test "$(cur)" = DETACHED
git switch -q main
REF="" SHA="$(git rev-parse feature)"
run_task "$CHECKOUT" n >/dev/null
check "コミット行からは y/N で確認する (n でキャンセル)" test "$(cur)" = main
run_task "$CHECKOUT" y >/dev/null 2>&1
check "コミット行からは detached HEAD でチェックアウトする" \
  test "$(cur)" = DETACHED -a "$(git rev-parse HEAD)" = "$SHA"
out="$(run_task "$CHECKOUT" y 2>&1)"
check "既にそのコミットなら何もしない" grep -q '既にこのコミット' <<<"$out"
git switch -q main

echo "== create branch"
REF="" SHA="$(git rev-parse feature)"
run_task "$CREATE" $'new-a\nn' >/dev/null 2>&1
check "名前を入力し、n ならチェックアウトせずに作る" \
  test "$(git rev-parse -q --verify new-a)" = "$SHA" -a "$(cur)" = main
out="$(run_task "$CREATE" $'bad..name\nnew-a\n  new-b  \ny' 2>&1)"
check "使えない名前は聞き直す" grep -q 'ブランチ名として使えません' <<<"$out"
check "既にある名前は聞き直す" grep -q '既にあります' <<<"$out"
check "前後の空白を取り除き、y ならチェックアウトもする" \
  test "$(cur)" = new-b -a "$(git rev-parse HEAD)" = "$SHA"
git switch -q main
run_task "$CREATE" "" >/dev/null 2>&1
check "空入力ならキャンセルして成功扱い (exit 0)" test $? -eq 0

echo "== merge"
REF=feature SHA="$(git rev-parse feature)"
run_task "$MERGE" 1 >/dev/null 2>&1
check "ブランチラベルから: 1 で通常のマージ" git merge-base --is-ancestor feature HEAD
git reset -q --hard "$base"
run_task "$MERGE" 2 >/dev/null 2>&1
check "ブランチラベルから: 2 で --no-ff (マージコミットを作る)" \
  test "$(subject)" = "Merge branch 'feature'" -a "$(count_parents)" = 2
git reset -q --hard "$base"
out="$(run_task "$MERGE" 3 2>&1)"
check "ブランチラベルから: 3 で --squash (コミットせずにステージ)" \
  test "$(git rev-parse HEAD)" = "$base" -a "$(git diff --cached --name-only)" = f.txt
check "--squash ではコミットするよう案内する" grep -q 'Git Panel からコミット' <<<"$out"
git reset -q --hard "$base"
REF=""
run_task "$MERGE" 2 >/dev/null 2>&1
check "コミット行から: コミットをマージできる" \
  grep -q "^Merge commit '$SHA'" <<<"$(subject)"
git reset -q --hard "$base"
out="$(REF=main SHA="$base" run_task "$MERGE" 1 2>&1)"
check "現在のブランチ自身はマージしない" grep -q '現在のブランチ自身はマージできません' <<<"$out"

echo "== rebase"
git switch -q -c topic "$base" && commit_file t.txt t t1
t1="$(git rev-parse topic)"
git switch -q main && commit_file m.txt m m1
m1="$(git rev-parse main)"
git switch -q topic
REF="" SHA="$m1"
run_task "$REBASE" "" >/dev/null
check "空入力ならキャンセル" test "$(git rev-parse topic)" = "$t1"
run_task "$REBASE" 1 >/dev/null 2>&1
check "コミット行から: そのコミットの上にリベースできる" git merge-base --is-ancestor "$m1" topic
git reset -q --hard "$t1"
REF=main run_task "$REBASE" 1 >/dev/null 2>&1
check "ブランチラベルから: そのブランチの上にリベースできる" git merge-base --is-ancestor main topic
git reset -q --hard "$t1"
export GIT_SEQUENCE_EDITOR=true
out="$(REF=main run_task "$REBASE" 2 2>&1)"
unset GIT_SEQUENCE_EDITOR
check "2 で interactive (git rebase -i)" grep -q 'git rebase -i main' <<<"$out"
check "interactive でもリベースできる" git merge-base --is-ancestor main topic
git switch -q main && git reset -q --hard "$base"

echo "== cherry-pick / revert"
git switch -q -c pick-src "$base" && commit_file p.txt p p1 && git switch -q main
REF="" SHA="$(git rev-parse pick-src)"
run_task "$PICK" "" >/dev/null
check "cherry-pick: 空入力ならキャンセル" test "$(git rev-parse HEAD)" = "$base"
run_task "$PICK" 1 >/dev/null 2>&1
check "cherry-pick: 1 で取り込める" test "$(subject)" = p1 -a -f p.txt
git reset -q --hard "$base"
run_task "$PICK" 2 >/dev/null 2>&1
check "cherry-pick: 2 (-x) で元のコミットが記録される" \
  grep -q "cherry picked from commit $SHA" <<<"$(git log -1 --format=%B)"
git reset -q --hard "$base"
out="$(run_task "$PICK" 3 2>&1)"
check "cherry-pick: 3 (--no-commit) でコミットせずにステージだけする" \
  test "$(git rev-parse HEAD)" = "$base" -a "$(git diff --cached --name-only)" = p.txt
check "cherry-pick --no-commit: コミットするよう案内する" grep -q 'Git Panel からコミット' <<<"$out"
git reset -q --hard "$base"
REF=pick-src run_task "$PICK" 1 >/dev/null 2>&1
check "cherry-pick: ブランチラベルからも使える" test "$(subject)" = p1
git reset -q --hard "$base"

git switch -q -c side "$base" && commit_file s.txt s s1 && git switch -q -c merged "$base" &&
  git merge -q --no-ff --no-edit side && git switch -q main
REF="" SHA="$(git rev-parse merged)"
out="$(run_task "$PICK" 1 2>&1)"
check "cherry-pick: マージコミットは -m 1 で取り込める" test -f s.txt
check "cherry-pick: マージコミットであることを表示する" grep -q 'マージコミット' <<<"$out"
git reset -q --hard "$base"

commit_file r.txt r r1
SHA="$(git rev-parse HEAD)"
run_task "$REVERT" n >/dev/null
check "revert: n ならキャンセル" test "$(git rev-parse HEAD)" = "$SHA"
run_task "$REVERT" y >/dev/null 2>&1
check "revert: y で打ち消しコミットを作る" test "$(subject)" = 'Revert "r1"' -a ! -e r.txt
git reset -q --hard "$base"
git merge -q --no-ff --no-edit side
SHA="$(git rev-parse HEAD)"
run_task "$REVERT" y >/dev/null 2>&1
check "revert: マージコミットは -m 1 で打ち消せる" test ! -e s.txt
git reset -q --hard "$base"

echo "== continue / abort"
REF="" SHA="$base"
out="$(run_task "$CONTINUE" "" 2>&1)"
check "Continue: 途中の操作が無ければ何もしない" grep -q 'はありません' <<<"$out"
out="$(run_task "$ABORT" y 2>&1)"
check "Abort: 途中の操作が無ければ何もしない" grep -q 'はありません' <<<"$out"

git switch -q -c conflict-a "$base" && commit_file c.txt a a && git switch -q main && commit_file c.txt b b
REF=conflict-a SHA="$(git rev-parse conflict-a)"
out="$(run_task "$MERGE" 1 2>&1)"
check "merge: コンフリクト時に Continue / Abort を案内する" grep -q '「Continue」' <<<"$out"
out="$(run_task "$CONTINUE" "" 2>&1)"
check "Continue: 未解決のコンフリクトがあれば止める" grep -q '未解決のコンフリクト' <<<"$out"
check "Continue: 止めたときはマージ中のまま" git rev-parse -q --verify MERGE_HEAD
check "Continue: 止めたときは成功扱いにしない" test "$(run_task "$CONTINUE" "" >/dev/null 2>&1; echo $?)" != 0
echo resolved >c.txt && git add c.txt
run_task "$CONTINUE" "" >/dev/null 2>&1
check "Continue: merge を完了できる (エディタを開かない)" \
  test -z "$(git rev-parse -q --verify MERGE_HEAD)" -a "$(count_parents)" = 2
git reset -q --hard HEAD~1

run_task "$MERGE" 1 >/dev/null 2>&1
run_task "$ABORT" n >/dev/null
check "Abort: n ならキャンセル" git rev-parse -q --verify MERGE_HEAD
run_task "$ABORT" y >/dev/null 2>&1
check "Abort: merge を中止できる" test -z "$(git rev-parse -q --verify MERGE_HEAD)"

REF=""
run_task "$PICK" 1 >/dev/null 2>&1
check "cherry-pick: コンフリクトで止まる" git rev-parse -q --verify CHERRY_PICK_HEAD
run_task "$ABORT" y >/dev/null 2>&1
check "Abort: cherry-pick を中止できる" \
  test -z "$(git rev-parse -q --verify CHERRY_PICK_HEAD)" -a "$(subject)" = b

commit_file c.txt c c && commit_file c.txt d d
SHA="$(git rev-parse HEAD~1)"
run_task "$REVERT" y >/dev/null 2>&1
check "revert: コンフリクトで止まる" git rev-parse -q --verify REVERT_HEAD
echo resolved >c.txt && git add c.txt
run_task "$CONTINUE" "" >/dev/null 2>&1
check "Continue: revert を完了できる" \
  test -z "$(git rev-parse -q --verify REVERT_HEAD)" -a "$(subject)" = 'Revert "c"'

REF=conflict-a SHA="$(git rev-parse conflict-a)"
out="$(run_task "$REBASE" 1 2>&1)"
check "rebase: コンフリクト時に案内が出る" grep -q '「Continue」' <<<"$out"
echo resolved >c.txt && git add c.txt
out="$(run_task "$CONTINUE" "" 2>&1)"
while grep -q '途中で止まっています' <<<"$out"; do
  echo resolved >c.txt && git add c.txt
  out="$(run_task "$CONTINUE" "" 2>&1)"
done
check "Continue: rebase を最後まで続行できる" test ! -d "$(git rev-parse --git-path rebase-merge)"
check "rebase: 結果に conflict-a が含まれる" git merge-base --is-ancestor conflict-a HEAD

echo "== SSH 接続先 (偽の ssh で確認)"
# 偽の ssh: 接続先の名前を記録し、残りの引数を「接続先」(HOME と PATH を差し替えた sh) で実行する。
# 本物の ssh も、引数をつないだ文字列を接続先のログインシェルに -c で渡す
cat >"$WORK/fake-ssh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$FAKE_SSH_LOG"
shift
[ -n "${FAKE_SSH_FAIL:-}" ] && exit 255
HOME="$FAKE_REMOTE_HOME" PATH="${FAKE_REMOTE_PATH:-$PATH}" exec sh -c "$*"
EOF
chmod +x "$WORK/fake-ssh"
export ZGT_SSH="$WORK/fake-ssh" FAKE_SSH_LOG="$WORK/ssh-host" FAKE_REMOTE_HOME="$WORK/remote-home"
mkdir -p "$FAKE_REMOTE_HOME"
REMOTE_DIR="$FAKE_REMOTE_HOME/.local/share/zed-git-graph-tasks"
for k in MSG_RUNNER_MISSING; do
  check "$k は sh の '...' に入れられる (' と %s 以外の % を含まない)" \
    test -z "$( (. "$ROOT/lang/en.sh"; printf '%s\n' "${!k}"; . "$ROOT/lang/ja.sh"; printf '%s\n' "${!k}") |
      grep -e "'" -e '%[^s]')"
done
cp "$TASKS" "$WORK/before-remote"
"$ROOT/install.sh" --remote devbox --dry-run >/dev/null
check "--remote --dry-run では接続先に書かない" test ! -e "$REMOTE_DIR"
out="$("$ROOT/install.sh" --remote devbox 2>&1)"
check "--remote で接続先に zgt-run を置く" test -x "$REMOTE_DIR/zgt-run"
check "接続先のメッセージはローカルで選んだ言語 (ja)" cmp -s "$REMOTE_DIR/messages.sh" "$ROOT/lang/ja.sh"
check "指定した接続先に ssh する" test "$(cat "$FAKE_SSH_LOG")" = devbox
check "--remote ではローカルの tasks.json を変えない" cmp -s "$TASKS" "$WORK/before-remote"
check "bash と git があれば注意は出さない" test -z "$(grep '注意' <<<"$out")"

REF="" SHA="$base"
out="$(HOME="$FAKE_REMOTE_HOME" run_task "$CONTINUE" "" 2>&1)"
check "接続先 (HOME が違うマシン) でも tasks.json の定義のまま zgt-run が動く" \
  grep -q '途中で止まっている merge / rebase / cherry-pick / revert はありません' <<<"$out"
"$ROOT/install.sh" --remote devbox --lang en >/dev/null
out="$(HOME="$FAKE_REMOTE_HOME" run_task "$CONTINUE" "" 2>&1)"
check "--remote --lang en で接続先だけ英語になる" \
  test -n "$(grep 'No merge / rebase' <<<"$out")" -a "$(zgt_state_get "$STATE" lang)" = ja
mkdir -p "$WORK/empty-home"
out="$(HOME="$WORK/empty-home" run_task "$CONTINUE" "" 2>&1)"
check "zgt-run が無いホストでは入れ方を表示する (exit 127)" \
  test "$(HOME="$WORK/empty-home" run_task "$CONTINUE" "" >/dev/null 2>&1; echo $?)" = 127 \
  -a -n "$(grep -F 'には zgt-run がありません。Zed を動かしているマシンで ./install.sh --remote' <<<"$out")"
sed 's/^ZGT_PROTOCOL=.*/ZGT_PROTOCOL=0/' "$ROOT/bin/zgt-run" >"$REMOTE_DIR/zgt-run"
out="$(HOME="$FAKE_REMOTE_HOME" run_task "$CONTINUE" "" 2>&1)"
check "接続先の zgt-run が古ければ更新するよう表示する" grep -q 'too old to run this task' <<<"$out"

mkdir -p "$WORK/remote-bin"
for c in sh tar mkdir chmod; do ln -s "$(command -v "$c")" "$WORK/remote-bin/$c"; done
out="$(FAKE_REMOTE_PATH="$WORK/remote-bin" "$ROOT/install.sh" --remote devbox 2>&1)"
check "接続先に bash / git が無ければ注意を出す" \
  test -n "$(grep '注意: devbox に bash' <<<"$out")" -a -n "$(grep '注意: devbox に git' <<<"$out")"
out="$(FAKE_SSH_FAIL=1 "$ROOT/install.sh" --remote devbox 2>&1)"
check "接続に失敗したら失敗として終える" grep -q 'devbox への接続か書き込みに失敗しました' <<<"$out"
"$ROOT/uninstall.sh" --remote devbox --dry-run >/dev/null
check "uninstall --remote --dry-run では消さない" test -e "$REMOTE_DIR/zgt-run"
"$ROOT/uninstall.sh" --remote devbox >/dev/null
check "uninstall --remote で接続先から取り除く" test ! -e "$REMOTE_DIR"
check "uninstall --remote ではローカルのラッパーを残す" test -x "$RUNNER"

echo "== 英語の表示"
git reset -q --hard "$base"
"$ROOT/install.sh" --lang en >/dev/null
REF="" SHA="$base"
out="$(run_task "$CONTINUE" "" 2>&1)"
check "Continue: 英語で表示する" grep -q 'No merge / rebase / cherry-pick / revert in progress.' <<<"$out"
REF=feature SHA="$(git rev-parse feature)"
out="$(run_task "$MERGE" "" 2>&1)"
check "merge: 選択肢とキャンセルを英語で表示する" \
  test -n "$(grep 'Merge feature into the current branch. Choose how:' <<<"$out")" \
  -a -n "$(grep 'Cancelled\.' <<<"$out")"
out="$(run_task "$PUSH" "" 2>&1)"
check "push: ラベルを英語で表示する" grep -q '^Upstream   origin/feature' <<<"$out"

cd "$ROOT" || exit 1
"$ROOT/uninstall.sh" --purge >/dev/null

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]

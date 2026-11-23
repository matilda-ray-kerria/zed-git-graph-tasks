#!/usr/bin/env bash
# install.sh / uninstall.sh / zgt-run のテスト。一時ディレクトリだけを使い、実際の Zed 設定には触れない。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/zgt-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export ZED_CONFIG_DIR="$WORK/zed"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_NOSYSTEM=1
git config --global user.name test
git config --global user.email test@example.com
git config --global init.defaultBranch main
# エディタが開かれたら失敗させる (タスクがエディタ待ちで止まらないことを確かめる)
export GIT_EDITOR=false

TASKS="$ZED_CONFIG_DIR/tasks.json"
RUNNER="$ZED_CONFIG_DIR/zed-git-graph-tasks/zgt-run"
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
count_ours() { zgt_jsonc_to_json "$TASKS" | jq --arg r "$RUNNER" '[.[] | select(.command == $r)] | length'; }

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
cp "$TASKS" "$WORK/first"
"$ROOT/install.sh" >/dev/null
check "再インストールしても内容が変わらない" cmp -s "$TASKS" "$WORK/first"
"$ROOT/uninstall.sh" >/dev/null
check "自分で作った tasks.json はアンインストールで消える" test ! -e "$TASKS"
check "ラッパーが消える" test ! -e "$RUNNER"

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

# ---- ここからタスクの実行 (Zed の代わりに tasks.json から実行する) ----
"$ROOT/install.sh" >/dev/null
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
PUSH='Push ${ZED_GIT_REF} → origin…'
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

cd "$ROOT" || exit 1
"$ROOT/uninstall.sh" --purge >/dev/null

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]

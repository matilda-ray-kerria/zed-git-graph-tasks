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

# Zed の代わりに tasks.json のタスクを実行する: run_task <ラベル(テンプレート)> <ref> <stdin の答え>
run_task() {
  local label="$1" ref="$2" answer="$3" line
  local -a cmd=() envs=()
  while IFS= read -r line; do cmd+=("$line"); done < <(
    zgt_jsonc_to_json "$TASKS" | jq -r --arg l "$label" --arg ref "$ref" '
      .[] | select(.label == $l) | ([.command] + .args)[] | gsub("\\$\\{ZED_GIT_REF\\}"; $ref)')
  while IFS= read -r line; do envs+=("$line"); done < <(
    zgt_jsonc_to_json "$TASKS" | jq -r --arg l "$label" '
      .[] | select(.label == $l) | (.env // {}) | to_entries[] | "\(.key)=\(.value)"')
  [ ${#cmd[@]} -gt 0 ] || {
    echo "task not found: $label" >&2
    return 99
  }
  printf '%s\n' "$answer" | env ${envs[@]+"${envs[@]}"} "${cmd[@]}"
}

echo "== build"
check "断片ファイルを結合できる" "$ROOT/build.sh"
total="$("$ROOT/build.sh" | jq 'length')"
check "全タスクに git-command タグがある" \
  test "$("$ROOT/build.sh" | jq '[.[] | select(.tags | index("git-command"))] | length')" = "$total"
check "\$ZED_GIT_REF は \${...} 形式だけを使う (日本語が変数名に含まれないように)" \
  test -z "$(grep -n '\$ZED_' "$ROOT"/tasks.d/*.json)"

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

echo "== タスクの実行 (Zed の代わりに tasks.json から実行)"
"$ROOT/install.sh" >/dev/null
git init -q --bare "$WORK/remote.git"
git clone -q "$WORK/remote.git" "$WORK/repo" 2>/dev/null
cd "$WORK/repo" || exit 1
git commit -q --allow-empty -m base
git push -q origin main 2>/dev/null
git switch -q -c feature
echo feature >f.txt && git add f.txt && git commit -q -m feature
git switch -q main

PUSH='Push ${ZED_GIT_REF} → origin'
run_task "$PUSH" feature n >/dev/null
check "push: n ならキャンセル" test -z "$(git ls-remote origin refs/heads/feature)"
run_task "$PUSH" feature "" </dev/null >/dev/null
check "push: 空入力ならキャンセル" test -z "$(git ls-remote origin refs/heads/feature)"
run_task "$PUSH" feature y >/dev/null 2>&1
check "push: y でチェックアウトしていないブランチを push できる" test -n "$(git ls-remote origin refs/heads/feature)"
check "push: upstream が設定される" test "$(git config branch.feature.merge)" = refs/heads/feature
run_task "$PUSH" origin/main y >/dev/null 2>&1
check "push: リモートブランチのラベルではエラーで止まる" test -z "$(git ls-remote origin refs/heads/origin/main)"

git switch -q feature
git commit -q --amend -m "feature (amended)"
git switch -q main
LEASE='Push ${ZED_GIT_REF} → origin (force-with-lease)'
run_task "$LEASE" feature y >/dev/null 2>&1
check "force-with-lease: y では実行しない (yes が必要)" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" != "$(git rev-parse feature)"
run_task "$LEASE" feature yes >/dev/null 2>&1
check "force-with-lease: yes で上書きできる" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git rev-parse feature)"

git clone -q "$WORK/remote.git" "$WORK/other" 2>/dev/null
(cd "$WORK/other" && git switch -q feature && echo other >o.txt && git add o.txt &&
  git commit -q -m other && git push -q origin feature 2>/dev/null)
git switch -q feature
git commit -q --amend -m "feature (amended again)"
git switch -q main
git fetch -q origin
run_task "$LEASE" feature yes >/dev/null 2>&1
check "force-with-lease: 他人の push を取り込まずに fetch だけした状態では拒否される" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" != "$(git rev-parse feature)"
run_task 'Push ${ZED_GIT_REF} → origin (force)' feature yes >/dev/null 2>&1
check "force: yes で無条件に上書きできる" \
  test "$(git ls-remote origin refs/heads/feature | cut -f1)" = "$(git rev-parse feature)"

MERGE='Merge ${ZED_GIT_REF} into current branch'
run_task "$MERGE" feature n >/dev/null
check "merge: n ならキャンセル" test -z "$(git branch --merged main --list feature)"
run_task "$MERGE" feature y >/dev/null
check "merge: y でマージできる" test -n "$(git branch --merged main --list feature)"
git reset -q --hard HEAD~0 && git reset -q --hard origin/main

git switch -q -c conflict-a && echo a >c.txt && git add c.txt && git commit -q -m a
git switch -q main && echo b >c.txt && git add c.txt && git commit -q -m b
out="$(run_task "$MERGE" conflict-a y 2>&1)"
check "merge: コンフリクト時に案内が出る" grep -q 'Merge: abort' <<<"$out"
out="$(run_task 'Rebase: continue' x y 2>&1)"
check "Rebase: continue はリベース中でなければ何もしない" grep -q '進行中のリベースはありません' <<<"$out"
run_task 'Merge: abort' x n >/dev/null
check "Merge: abort は n ならキャンセル" git rev-parse -q --verify MERGE_HEAD
run_task 'Merge: abort' x y >/dev/null
check "Merge: abort は y で中止できる" test -z "$(git rev-parse -q --verify MERGE_HEAD)"

out="$(run_task 'Rebase current branch on ${ZED_GIT_REF}' conflict-a y 2>&1)"
check "rebase: コンフリクト時に案内が出る" grep -q 'Rebase: continue' <<<"$out"
echo resolved >c.txt && git add c.txt
run_task 'Rebase: continue' x "" >/dev/null 2>&1
check "Rebase: continue は確認なし・エディタなしで続行できる" test ! -d "$(git rev-parse --git-path rebase-merge)"
check "rebase: 結果に conflict-a が含まれる" git merge-base --is-ancestor conflict-a HEAD

cd "$ROOT" || exit 1
"$ROOT/uninstall.sh" --purge >/dev/null

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]

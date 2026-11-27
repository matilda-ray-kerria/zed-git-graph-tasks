#!/usr/bin/env bash
# tasks.d/*.json (断片ファイル) を結合し、1 つの JSON 配列として標準出力に出す
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

# メッセージの言語は環境変数 ZGT_LANG (install.sh が渡す)。無い / 不明なら英語
zgt_load_lang "${ZGT_LANG:-en}" || zgt_load_lang en

expand=0
while [ $# -gt 0 ]; do
  case "$1" in
    --expand)
      expand=1
      shift
      ;;
    -h | --help)
      printf '%s\n' "$MSG_BUILD_USAGE"
      exit 0
      ;;
    *) zgt_die "$(zgt_msg UNKNOWN_ARG "$1")" ;;
  esac
done

zgt_require jq

shopt -s nullglob
files=("$ZGT_ROOT"/tasks.d/*.json)
[ ${#files[@]} -gt 0 ] || zgt_die "$(zgt_msg NO_FRAGMENTS)"

for f in "${files[@]}"; do
  jq -e 'type == "array" and all(.[]; type == "object"
           and (.label | type) == "string" and (.command | type) == "string")' \
    "$f" >/dev/null || zgt_die "$(zgt_msg BAD_FRAGMENT "$f")"
done

if [ "$expand" -eq 0 ]; then
  jq -s --indent 2 'add' "${files[@]}"
  exit 0
fi

# "command": "__ZGT_RUN__" のタスクを "command": "sh -c '<起動スクリプト>'" に置き換える。
# Zed は args を引用符なしで利用者のシェルに渡すので、args は残さない (lib/common.sh の zgt_loader):
#   - 記号を含まない語 (サブコマンド名や --confirm など) は起動スクリプトにそのまま書く
#   - それ以外 (${ZED_...} や空白・記号を含むもの) は env の ZGT_ARG<n> に移し、
#     起動スクリプトから "$ZGT_ARG<n>" で渡す
loader="$(zgt_loader)" || exit 1
jq -s --indent 2 --arg placeholder "$ZGT_PLACEHOLDER" --arg loader "$loader" \
  --arg token "$ZGT_ARGS_TOKEN" '
  add | map(if .command != $placeholder then . else
    .label as $label
    | (if (.env // {}) | keys | any(test("^(ZGT_|GIT_CONFIG_)"; "i"))
       then error("\($label): env must not define ZGT_* or GIT_CONFIG_* (used by the launcher)") else . end)
    | (reduce (.args // [])[] as $a ({words: [], env: {}, n: 0};
        if ($a | type) != "string" then error("\($label): args must be strings")
        elif ($a | test("^[A-Za-z0-9_.,:/@%+=-]+$")) then .words += [$a]
        else .n += 1 | .env["ZGT_ARG\(.n)"] = $a | .words += ["\"$ZGT_ARG\(.n)\""]
        end)) as $r
    | .command = ($loader | split($token) | .[0] + ($r.words | join(" ")) + .[1])
    | del(.args)
    | if ($r.env | length) > 0 then .env = ((.env // {}) + $r.env) else . end
  end)' "${files[@]}"

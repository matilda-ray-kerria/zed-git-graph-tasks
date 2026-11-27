# tasks.json から zgt-run を起動する sh のスクリプト (1 行) のひな形。# で始まる行と空行は読み飛ばす。
# lib/common.sh の zgt_loader (macOS / Linux: "command": "sh -c '<これ>'") と
# lib/common.ps1 の Get-ZgtLauncher (Windows: git のエイリアス "!<これ>" を env で渡し "git zgt-run") が読む。
#
#   @NAME@      zed-git-graph-tasks
#   @PROTOCOL@  bin/zgt-run の ZGT_PROTOCOL
#   @MSG@       MSG_RUNNER_MISSING (表示の言語のもの)
#   @ARGS@      zgt-run に渡す引数。記号の無い語はそのまま、それ以外は "$ZGT_ARG<n>" (値は env)
#
# - zgt-run の場所: env の ZGT_RUNNER (Windows の install.ps1 が入れる) があればそれ。
#   無ければ実行したマシンの $HOME/.local/share/@NAME@/zgt-run (SSH 接続先でも同じ定義で動く)
# - Windows では git が Git for Windows の sh でエイリアスを実行する。zgt-run が使う coreutils の
#   ため /usr/bin (Git の usr\bin) を PATH の先頭に足し、同じ Git の bash で zgt-run を実行する
# - Zed は command と env の中の $VAR を、ZED_ で始まらなければそのまま残す。ただし $$ は $ に、
#   ${...} は変数として扱うので、どちらも書かない。' も書かない (macOS / Linux では '...' の中に入る)
r=$ZGT_RUNNER; if [ -n "$r" ] && [ -f "$r" ]; then PATH=/usr/bin:$PATH; else r=$HOME/.local/share/@NAME@/zgt-run; fi; if [ -f "$r" ]; then export ZGT_REQUIRED_PROTOCOL=@PROTOCOL@; exec bash "$r" @ARGS@; fi; printf "@MSG@\n" "$(uname -n)" >&2; exit 127

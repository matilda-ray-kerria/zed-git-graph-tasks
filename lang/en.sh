# shellcheck shell=bash disable=SC2034
# English messages (the default). Keep the keys and the number / order of %s and %d
# in sync with lang/ja.sh (checked by test/run.sh).

MSG_LANG_NAME="English"

# ---- zgt-run ----
MSG_LABEL_REPO="Repository "
MSG_LABEL_BRANCH="Branch     "
MSG_LABEL_TARGET="Target     "
MSG_LABEL_COMMAND="Command    "
MSG_LABEL_UPSTREAM="Upstream   "
MSG_NONE="none"
MSG_USAGE="Usage: %s"
MSG_NEEDS_VALUE="%s requires a value"
MSG_UNKNOWN_OPTION="Unknown option: %s"
MSG_NO_COMMAND="No command to run"
MSG_BAD_REQUIRE="--require must be one of merge / rebase / cherry-pick / revert"
MSG_CANCELLED="Cancelled."
MSG_NOT_REPO="Not a Git repository: %s"
MSG_COMMIT_NOT_FOUND="Commit not found: %s"
MSG_REF_NOT_FOUND="Not found: %s"
MSG_ASK_CONFIRM="Run this? [y/N] "
MSG_ASK_DANGER="Type yes to run:"
MSG_CHOOSE_PROMPT="Choose a number (empty / q to cancel): "
MSG_CHOOSE_INVALID="Enter a number from 1 to %d."
MSG_FZF_HINT="(type to filter / Enter to select / Esc to cancel)"
MSG_DONE="✓ Done"
MSG_PRESS_ENTER="(Press Enter to close)"
MSG_FAILED="✗ Failed (exit %d)"
MSG_STOPPED="The %s stopped partway. Resolve the conflicts, stage them, and run \"Continue\" from Custom Commands (or \"Abort\" to cancel)."
MSG_MERGE_PANEL_HINT="You can also finish the merge by committing from the Git Panel."
MSG_NOT_IN_PROGRESS="No %s in progress."
MSG_NOTHING_IN_PROGRESS="No merge / rebase / cherry-pick / revert in progress."
MSG_NOTE_STAGED="The changes are staged. Commit them from the Git Panel."

MSG_ALREADY_CHECKED_OUT="%s is already checked out."
MSG_SWITCH_TO_BRANCH="Switch to branch %s"
MSG_NO_REMOTE_FOR="Cannot determine the remote of %s"
MSG_SWITCH_TRACKING="Switch to the local branch that tracks %s (%s)"
MSG_SWITCH_EXISTING="Switch to the existing local branch %s (upstream: %s)"
MSG_CREATE_TRACKING="Create a local branch that tracks %s (%s) and switch to it"
MSG_TAG_DETACHED="Checks out tag %s as a detached HEAD."
MSG_REF_MISSING="Branch / tag not found: %s"
MSG_CHECKOUT_TITLE="Choose how to check out:"
MSG_CHECKOUT_DETACHED_OPT="Check out commit %s as a detached HEAD"
MSG_ALREADY_AT_COMMIT="This commit is already checked out."
MSG_DETACHED_WARN="Checks out this commit as a detached HEAD. Create a branch if you want to keep working here."

MSG_NEW_BRANCH_PROMPT="New branch name (empty to cancel): "
MSG_BAD_BRANCH_NAME="Not a valid branch name: %s"
MSG_BRANCH_EXISTS="Already exists: %s"
MSG_ASK_CHECKOUT_TOO="Check it out as well? [y/N] "

MSG_MERGE_SELF="Cannot merge the current branch into itself."
MSG_MERGE_TITLE="Merge %s into the current branch. Choose how:"
MSG_MERGE_OPT_NORMAL="Normal      git merge"
MSG_MERGE_OPT_NOFF="--no-ff     Create a merge commit even if fast-forward is possible"
MSG_MERGE_OPT_SQUASH="--squash    Squash the changes into one and stage them (no commit)"

MSG_REBASE_TITLE="Rebase the current branch onto %s. Choose how:"
MSG_REBASE_OPT_NORMAL="Normal         git rebase"
MSG_REBASE_OPT_INTERACTIVE="interactive    git rebase -i (reorder / edit commits in your Git editor)"

MSG_PICK_DESC="Applies the changes of this commit to the current branch."
MSG_REVERT_DESC="Creates a commit on the current branch that undoes this commit."
MSG_MERGE_COMMIT_NOTE="This is a merge commit, so its first parent is used as the mainline (-m 1)."
MSG_PICK_TITLE="Choose how to cherry-pick:"
MSG_PICK_OPT_NORMAL="Normal        git cherry-pick"
MSG_PICK_OPT_X="-x            Record the original commit in the message"
MSG_PICK_OPT_NOCOMMIT="--no-commit   Only apply and stage the changes (no commit)"

MSG_LOCAL_UPSTREAM="%s (local branch)"
MSG_NOT_LOCAL_BRANCH="%s is not a local branch, so it cannot be pushed."
MSG_NO_SUCH_REMOTE="Remote %s does not exist."
MSG_NO_REMOTES="No remotes are configured."
MSG_PUSH_REMOTE_TITLE="Choose the remote to push to:"
MSG_PUSH_REMOTE_DEFAULT="(default)"
MSG_PUSH_TARGET_DIFF="%s → %s (%s: %s ahead / %s behind, as of the last fetch)"
MSG_PUSH_TARGET_NEW="%s → %s (not on %s yet)"
MSG_PUSH_TITLE="Choose how to push:"
MSG_PUSH_OPT_NORMAL="Normal              git push"
MSG_PUSH_OPT_LEASE="force-with-lease    Overwrite, but abort if someone else pushed since your last fetch"
MSG_PUSH_OPT_FORCE="force               Overwrite unconditionally (commits pushed by others are lost)"
MSG_ASK_UPSTREAM="Set upstream to %s? (current: %s) [y/N] "
MSG_LEASE_WARN="Overwrites %s with the local %s. Aborts if someone else pushed since your last fetch."
MSG_FORCE_WARN="Overwrites %s unconditionally. Commits pushed by others will be lost."

MSG_UNRESOLVED="There are unresolved conflicts. Resolve and stage them, then run this again:"
MSG_CONTINUE_DESC="Continues the %s in progress (without opening an editor; uses the message Git prepared)."
MSG_ABORT_DESC="Aborts the %s in progress and restores the state before it started (conflict resolutions are lost)."

# ---- install.sh / uninstall.sh / build.sh ----
MSG_REQUIRE_CMD="'%s' not found. Install it and run again."
MSG_UNKNOWN_ARG="Unknown argument: %s"
MSG_UNKNOWN_LANG="Unknown language '%s' (available: %s)"
MSG_BLOCK_NOTE="(managed by install.sh; do not edit inside this block)"
MSG_NO_FRAGMENTS="No tasks.d/*.json files"
MSG_BAD_FRAGMENT="Invalid fragment file: %s (it must be an array of objects with label and command)"
MSG_BUILD_FAILED="Failed to combine tasks.d"
MSG_TASKS_UNREADABLE="Could not read %s as a JSON array. Check its content (nothing was changed)"
MSG_NO_ARRAY_START="Could not find the opening [ of the array in %s (nothing was changed)"
MSG_BROKEN_MARKERS="The managed block markers in %s (%s / %s) are broken. Fix them by hand and run again (nothing was changed)"
MSG_VERIFY_FAILED="Failed to verify the result (nothing was changed)"
MSG_COUNT_MISMATCH="The number of tasks in the result does not match (expected %s / actual %s). Nothing was changed"
MSG_DRYRUN_INSTALL="# dry-run: changes to %s (nothing was written)"
MSG_UP_TO_DATE="tasks.json is up to date (%s tasks). Updated the wrapper: %s"
MSG_INSTALLED="✓ Added %s tasks: %s"
MSG_BACKUP_AT="  Backup:   %s"
MSG_RUNNER_AT="  Wrapper:  %s"
MSG_LANG_AT="  Language: %s (to change: ./install.sh --lang en|ja)"
MSG_HOW_TO_USE="In Zed's Git Graph, right-click a commit row or a branch label → Custom Commands."
MSG_DRYRUN="# dry-run (nothing was written)"
MSG_NO_BLOCK="No managed block in %s"
MSG_STRIP_VERIFY_FAILED="Could not verify the content after removing the block (nothing was changed)"
MSG_WILL_DELETE="Will delete %s (it was created by install.sh)"
MSG_WILL_REMOVE_RUNNER="Will remove zgt-run / messages.sh / state in %s"
MSG_WILL_PURGE="Will delete %s including the backups"
MSG_BLOCK_REMOVED="✓ Removed the managed block: %s"
MSG_DELETED="✓ Deleted %s (it was created by install.sh)"
MSG_PURGED="✓ Deleted %s"
MSG_PURGE_HINT="  (to delete the backups: ./uninstall.sh --purge)"
MSG_WILL_REMOVE_FILES="Will remove zgt-run / messages.sh in %s"

# ---- SSH hosts (install.sh / uninstall.sh --remote and the launcher in tasks.json) ----
# MSG_RUNNER_MISSING is embedded in printf "..." inside sh -c '...' in tasks.json: no ' " $ ` \, and no % except %s
MSG_RUNNER_MISSING="zgt-run is not installed on this host (%s). On the machine running Zed, run ./install.sh --remote <ssh host>."
MSG_RUNNER_OUTDATED="zgt-run on this host (%s) is too old to run this task. On the machine running Zed, run ./install.sh --remote <ssh host> to update it."
MSG_REMOTE_HINT="  To use it on SSH hosts too: ./install.sh --remote <ssh host> (once per host)"
MSG_REMOTE_DRYRUN="# dry-run: would put zgt-run and messages.sh on %s in %s (%s). Nothing was written"
MSG_REMOTE_DRYRUN_UNINSTALL="# dry-run: would remove zgt-run and messages.sh on %s from %s. Nothing was written"
MSG_REMOTE_INSTALLED="✓ Put zgt-run on %s: %s"
MSG_REMOTE_REMOVED="✓ Removed zgt-run from %s"
MSG_REMOTE_FAILED="Failed to connect to or write on %s"
MSG_REMOTE_MISSING_CMD="  Warning: on %s, %s was not found (required by zgt-run)"

MSG_BUILD_USAGE='Usage: ./build.sh [--expand]

Combines tasks.d/*.json in name order and prints the result to stdout.
  --expand  Replace "command": "__ZGT_RUN__" with a sh -c launcher that finds and runs zgt-run (used by install.sh)

Environment:
  ZGT_LANG  Message language (en / ja, default: en)'

MSG_INSTALL_USAGE='Usage: ./install.sh [--lang en|ja] [--dry-run]
       ./install.sh --remote <ssh host> [--lang en|ja] [--dry-run]

Combines tasks.d/*.json and adds them to the global Zed tasks.json as a managed block.
If the block is already there, it is replaced with the latest content.
Other tasks and comments are left untouched.
zgt-run and messages.sh are placed in ~/.local/share/zed-git-graph-tasks/.

  --lang en|ja     Message language (default: the previous choice, or en on the first install)
  --remote <host>  Only put zgt-run and messages.sh in ~/.local/share/zed-git-graph-tasks/ on an SSH host
                   (Zed runs tasks of SSH projects on the remote host. Run once per host)
  --dry-run        Only show what would change without writing

Environment:
  ZED_CONFIG_DIR  Zed config directory (default: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
  ZGT_SSH         ssh command used by --remote (default: ssh)'

MSG_UNINSTALL_USAGE='Usage: ./uninstall.sh [--dry-run] [--purge]
       ./uninstall.sh --remote <ssh host> [--dry-run]

Removes only the managed block from the global Zed tasks.json and deletes the wrapper.
Other tasks and comments are left untouched.

  --dry-run        Only show what would change without writing
  --purge          Also delete zed-git-graph-tasks/ in the config directory, including the backups
  --remote <host>  Only remove zgt-run and messages.sh on an SSH host

Environment:
  ZED_CONFIG_DIR  Zed config directory (default: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
  ZGT_SSH         ssh command used by --remote (default: ssh)'

# ---- install.ps1 / uninstall.ps1 (Windows) ----
# lib/common.ps1 reads these with its own parser (bash also sources this file): write each value
# as "..." or '...', and use single quotes for text that contains $ or \.
MSG_WINDOWS_ONLY_PS="install.ps1 / uninstall.ps1 are for Windows. On macOS / Linux, use ./install.sh / ./uninstall.sh"
MSG_NO_GIT_BASH_PS='Git Bash (bin\bash.exe of Git for Windows) was not found. Install Git for Windows (winget install --id Git.Git -e), or pass the path with -Bash'
MSG_BASH_NOT_FOUND_PS="Not found: %s (pass the path to bash.exe of Git for Windows with -Bash)"
MSG_BASH_AT_PS="  Git Bash: %s"
MSG_BLOCK_NOTE_PS="(managed by install.ps1; do not edit inside this block)"
MSG_LANG_AT_PS='  Language: %s (to change: .\install.ps1 -Lang en|ja)'
MSG_WILL_DELETE_PS="Will delete %s (it was created by install.ps1)"
MSG_DELETED_PS="✓ Deleted %s (it was created by install.ps1)"
MSG_PURGE_HINT_PS='  (to delete the backups: .\uninstall.ps1 -Purge)'

MSG_INSTALL_USAGE_PS='Usage: .\install.ps1 [-Lang en|ja] [-DryRun] [-Bash PATH]

Combines tasks.d\*.json and adds them to the global Zed tasks.json as a managed block.
If the block is already there, it is replaced with the latest content.
Other tasks and comments are left untouched. The tasks run zgt-run with Git Bash.

  -Lang en|ja  Message language (default: the previous choice, or en on the first install)
  -DryRun      Only show the diff without writing
  -Bash PATH   bash.exe of Git for Windows (default: the previous choice, or found automatically)

Environment:
  ZED_CONFIG_DIR  Zed config directory (default: $env:APPDATA\Zed)'

MSG_UNINSTALL_USAGE_PS='Usage: .\uninstall.ps1 [-DryRun] [-Purge]

Removes only the managed block from the global Zed tasks.json and deletes the wrapper.
Other tasks and comments are left untouched.

  -DryRun  Only show the diff without writing
  -Purge   Also delete zed-git-graph-tasks\ in the config directory, including the backups

Environment:
  ZED_CONFIG_DIR  Zed config directory (default: $env:APPDATA\Zed)'

#!/bin/sh
set -eu
umask 077

case $(uname -s) in
    Darwin) task_default_output_dir="$HOME/Library/Logs/Zed Test" ;;
    *) task_default_output_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zed-test" ;;
esac
task_output_dir=${ZED_TEST_DIAGNOSTIC_LOG_DIR:-$task_default_output_dir}
task_timestamp=$(/bin/date +%Y%m%d-%H%M%S)
task_log_dir="$task_output_dir/zed-test-diagnostics/$task_timestamp-$$"
/bin/mkdir -p "$task_log_dir"
: > "$task_log_dir/stdout.log"
: > "$task_log_dir/stderr.log"
task_app_binary=${ZED_TEST_DIAGNOSTIC_BINARY:-/Applications/Zed Test.app/Contents/MacOS/zed}
task_lifecycle_log="$task_log_dir/lifecycle.log"

printf 'started_at=%s\nwrapper_pid=%s\nbinary=%s\n' \
    "$(/bin/date -Iseconds)" "$$" "$task_app_binary" > "$task_lifecycle_log"
printf '%s\n' "$task_log_dir" > "$task_output_dir/zed-test-diagnostics/latest"

printf 'Zed Test diagnostic logs: %s\n' "$task_log_dir"
printf 'Running Zed directly so the wrapper can record its exit status.\n'

if [ ! -x "$task_app_binary" ]; then
    printf 'launch_error=executable_missing\nexit_code=127\n' >> "$task_lifecycle_log"
    printf 'Executable not found: %s\n' "$task_app_binary" >&2
    exit 127
fi

ZED_TEST_PROFILE_UI=1 "$task_app_binary" "$@" </dev/null >> "$task_log_dir/stdout.log" 2>> "$task_log_dir/stderr.log" &
task_app_pid=$!
printf 'app_pid=%s\n' "$task_app_pid" >> "$task_lifecycle_log"
printf 'Zed PID: %s\n' "$task_app_pid"

set +e
wait "$task_app_pid"
task_exit_code=$?
set -e
printf 'ended_at=%s\nexit_code=%s\n' \
    "$(/bin/date -Iseconds)" "$task_exit_code" >> "$task_lifecycle_log"
printf 'Zed exited with status %s. Logs: %s\n' "$task_exit_code" "$task_log_dir"
exit "$task_exit_code"

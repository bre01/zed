#!/bin/sh
set -eu

repository=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
cd "$repository"

case $(uname -s) in
    Darwin) default_data_dir="$HOME/Library/Application Support/Zed Test" ;;
    *) default_data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zed-test" ;;
esac

export ZED_RELEASE_CHANNEL=dev
export ZED_TEST_DATA_DIR="${ZED_TEST_DATA_DIR:-$default_data_dir}"
export CARGO_PROFILE_DEV_DEBUG=0
export CARGO_PROFILE_DEV_STRIP=none
export CARGO_PROFILE_DEV_BUILD_OVERRIDE_DEBUG=0
export CARGO_PROFILE_DEV_BUILD_OVERRIDE_STRIP=none
export CARGO_INCREMENTAL=0

exec cargo +1.97.1 build -p zed --bin zed --features util/debug-embed \
    -j "${ZED_TEST_BUILD_JOBS:-8}" \
    --config 'profile.dev.package.sqlez_macros.debug=1' \
    --config 'profile.dev.package.sqlez_macros.split-debuginfo="off"' \
    --config 'profile.dev.package.gpui.opt-level=2' \
    --config 'profile.dev.package.gpui_macos.opt-level=2' \
    --config 'profile.dev.package.ui.opt-level=2' \
    --config 'profile.dev.package.markdown.opt-level=2' \
    --config 'profile.dev.package.editor.opt-level=2' \
    --config 'profile.dev.package.agent_ui.opt-level=2' \
    --config 'profile.dev.package.workspace.opt-level=2' \
    --config 'profile.dev.package.ui_input.opt-level=2' "$@"

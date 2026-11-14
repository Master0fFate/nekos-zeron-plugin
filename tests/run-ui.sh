#!/usr/bin/env bash
set -eu
# Development tools: zgx plus a checkout of Zeron v0.3.4. No Python or npm.
plugin_dir=$(cd "$(dirname "$0")/.." && pwd)
zeron_ui=${1:?Usage: bash tests/run-ui.sh /path/to/zeron/apps/zgx/ui [zgx-binary]}
zgx_bin=${2:-zgx}
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
cp "$plugin_dir"/*.luau "$test_dir/"
cp -R "$zeron_ui/ds" "$test_dir/ds"
for assets in fonts assets; do
  if [ -d "$zeron_ui/$assets" ]; then cp -R "$zeron_ui/$assets" "$test_dir/$assets"; fi
done
cp "$plugin_dir/tests/ui/host.luau" "$test_dir/app.luau"
mkdir "$test_dir/tests"
cp "$plugin_dir/tests/ui/panel.test.luau" "$test_dir/tests/"
printf '%s\n' '{"aliases":{"ds":"./ds"}}' > "$test_dir/.luaurc"
printf '%s\n' '{"width":1180,"height":850}' > "$test_dir/zgx.json"
"$zgx_bin" test "$test_dir"

# shellcheck shell=sh

# bootstrap-salt.sh runs from the top and calls exit, so it cannot be sourced
# to get at its functions. Extract the top-level functions we want into a file
# that the specs can Include instead.
#
# Usage in a spec:  Include "$(bootstrap_functions __foo __bar)"
bootstrap_functions() {
    _out="${SHELLSPEC_TMPBASE:-${TMPDIR:-/tmp}}/bootstrap-functions.$$.sh"
    awk -v names=" $* " '
        /^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/ {
            name = $1
            sub(/\(\).*/, "", name)
            keep = index(names, " " name " ") > 0
        }
        keep { print }
        /^}/ { keep = 0 }
    ' "$SHELLSPEC_PROJECT_ROOT/bootstrap-salt.sh" > "$_out"
    echo "$_out"
}

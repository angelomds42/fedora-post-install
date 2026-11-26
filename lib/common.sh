if [[ -t 1 ]]; then
    readonly C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_RED=$'\e[31m' C_YELLOW=$'\e[33m' C_BLUE=$'\e[34m' C_GREEN=$'\e[32m'
else
    readonly C_RESET='' C_BOLD='' C_RED='' C_YELLOW='' C_BLUE='' C_GREEN=''
fi

info() { printf '%s::%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
step() { printf '\n%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }
warn() { printf '%swarning:%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()  { printf '%serror:%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

is_true() { [[ ${1,,} == true ]]; }

contains() {
    local needle=$1 item
    shift
    for item in "$@"; do
        [[ $item == "$needle" ]] && return 0
    done
    return 1
}

run() {
    if is_true "$DRY_RUN"; then
        printf '   $ %s\n' "$*"
        return 0
    fi
    "$@"
}

request_reboot() { : >"$STATE_DIR/reboot"; }

# Validate required variables are set
require_var() {
    local var_name=$1
    [[ -n ${!var_name:-} ]] || die "required variable not set: $var_name"
}
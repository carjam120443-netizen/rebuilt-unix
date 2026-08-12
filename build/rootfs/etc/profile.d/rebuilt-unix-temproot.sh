# Rebuilt Unix per-terminal temporary root workspace.
# Relative paths used by sudo commands start here for this terminal session.
# This does NOT sandbox absolute paths or filesystem writes outside this directory.

if [ -z "${REBUILT_UNIX_TEMP_ROOT:-}" ]; then
    REBUILT_UNIX_TEMP_ROOT="/temproot/$$"
    export REBUILT_UNIX_TEMP_ROOT
    mkdir -p "$REBUILT_UNIX_TEMP_ROOT" 2>/dev/null || true
fi

# Use sudo's chdir support so sudo commands begin in this session's temp root.
sudo() {
    command sudo -D "$REBUILT_UNIX_TEMP_ROOT" "$@"
}

export TMPDIR="$REBUILT_UNIX_TEMP_ROOT"

#!/bin/bash
# Returns 0 (true) if running inside Warp terminal on macOS, 1 otherwise.
is_warp_terminal() {
    [ "${TERM_PROGRAM}" = "WarpTerminal" ]
}

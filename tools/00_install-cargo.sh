#!/bin/sh

# Cargo will install to user's home dir by default
#
# curl arguments:
#     - -s: silent 
#     - -S: show error
#     - -f: fail with no output on server error
#
# rustup installer arguments:
#     - -q: quiet
#     - -y: disable confirmation prompt

 curl https://sh.rustup.rs -sSf | sh -s -- -q -y

#!/bin/sh

#
# git pre-commit hook
#
# Install by:
# $ ln -s ../../pre-commit.sh .git/hooks/pre-commit
#

set -eu

unset MIX_ENV
unset MIX_TARGET

# Make a pass through the most annoying checks to fail on CI
mix format --check-formatted
mix deps.unlock --check-unused
mix docs
mix hex.build
mix credo -a

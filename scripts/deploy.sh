#!/usr/bin/env bash

source .env
export FOUNDRY_PROFILE=production

echo Using profile: $FOUNDRY_PROFILE

# NOTE to add --broadcast flag when sending
# To use a different wallet index, add --mnemonic-indexes n where n is the index

# Testing

# Production

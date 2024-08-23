#!/bin/bash

set -eExuo pipefail

d=$(git rev-parse --show-toplevel)

source $d/lib/bashert.sh

params="$(cat << EOF
{
    "chain_id": 100,
    "safe_address": "0x38Ba7f4278A1482FA0a7bC8B261a9A673336EDDc",
    "message_hash": "0xa225aed0c0283cef82b24485b8b28fb756fc9ce83d25e5cf799d0c8aa20ce6b7"
}
EOF
)"

test_proving_ok() {
  printf "test_proving_ok\n"

  resp_head=$(mktemp)
  resp_body=$(mktemp)

  curl \
    -sS \
    -D $resp_head \
    http:/localhost:4190/proof \
    -d "$params" \
  > $resp_body

  assert_status $resp_head 200

  block_number=$(jq -r '.block_number' $resp_body)
  block_hash=$(jq -r '.block_hash' $resp_body)
  challenge=$(jq -r '.challenge' $resp_body)
  proof=$(jq -r '.proof' $resp_body)

  assert_gt $block_number 33119702
  assert_match $block_hash '^0x[a-f0-9]{64}$'
  assert_match $challenge '^0x[a-f0-9]{64}$'
  assert_match $proof '^0x[a-f0-9]+$'
}

test_proving_not_ok() {
  printf "test_proving_not_ok\n"

  resp_head=$(mktemp)
  resp_body=$(mktemp)
  # replace chain_id to point to non-existing contract storage
  not_ok_params="$(echo "$params" | sed 's/100/11155111/')"

  curl \
    -sS \
    -D $resp_head \
    http:/localhost:4190/proof \
    -d "$not_ok_params" \
  > $resp_body

  assert_status $resp_head 500
  err="$(jq -r '.error' $resp_body)"
  assert_equal "$err" 't(ツ)_/¯ invalid storage proof'
}

test_wrong_chain_id() {
  printf "test_wrong_chain_id\n"

  resp_head=$(mktemp)
  resp_body=$(mktemp)
  # replace chain_id to point to non-existing contract storage
  not_ok_params="$(echo "$params" | sed 's/100/999999999999999/')"

  curl \
    -sS \
    -D $resp_head \
    http:/localhost:4190/proof \
    -d "$not_ok_params" \
  > $resp_body

  assert_status $resp_head 400
  err="$(jq -r '.error' $resp_body)"
  assert_equal "$err" 't(ツ)_/¯ invalid chain id'
}

test_status() {
  printf "test_status\n"

  resp_head=$(mktemp)
  resp_body=$(mktemp)

  curl \
    -sS \
    -D $resp_head \
    http:/localhost:4190/status \
  > $resp_body

  assert_status $resp_head 200
  status="$(jq -r '.status' $resp_body)"
  assert_equal "$status" 'ok'
}

test_proving_ok
test_proving_not_ok
test_wrong_chain_id
test_status
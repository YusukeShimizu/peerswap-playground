#!/usr/bin/env sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

bitcoind() {
  $DIR/../bin/bitcoin-cli $@
}

elementsd() {
  $DIR/../bin/elements-cli $@
}

lnd1() {
  $DIR/../bin/lncli lnd1 $@
}

lnd2() {
  $DIR/../bin/lncli lnd2 $@
}

lwk() {
  $DIR/../bin/lwk-cli $@
}

lwk2() {
  $DIR/../bin/lwk2-cli $@
}


cln1() {
  $DIR/../bin/clncli $@
}

waitFor() {
  until $@; do
    >&2 echo "$@ unavailable - waiting..."
    sleep 1
  done
}

createBitcoindWallet() {
  $DIR/../bin/bitcoin-cli createwallet default || $DIR/../bin/bitcoin-cli loadwallet default || true
}

createElementsWallet() {
  elementsd createwallet "peerswap1" || true
  elementsd createwallet "peerswap2" || true

  elementsd -rpcwallet=peerswap1 -generate 3 0
  elementsd -rpcwallet=peerswap2 -generate 3 0

  elementsd -rpcwallet=peerswap1 rescanblockchain
  elementsd -rpcwallet=peerswap2 rescanblockchain

  elementsd -rpcwallet=peerswap1 getbalance
  elementsd -rpcwallet=peerswap2 getbalance
}

createLWKWallet() {
  MNEMONIC="current enforce ignore west hammer neutral obscure shiver say welcome you license"
  docker exec lnd_lwk-lwk-1 lwk_cli --network=regtest --addr=127.0.0.1:32113 signer load-software --signer s1 --mnemonic "$MNEMONIC" --persist true
  DESCRIPTOR=$(lwk signer singlesig-desc --signer s1 --descriptor-blinding-key slip77 --kind wpkh | jq -r .descriptor)
  lwk wallet load --wallet w1 -d "$DESCRIPTOR"
  sleep 10 # waiting for blocks to be propagated
  ADDRESS=$(lwk wallet address --wallet w1 | jq -r .address)
  elementsd -rpcwallet=peerswap1 sendtoaddress $ADDRESS 1
  elementsd -rpcwallet=peerswap1 -generate 3
  elementsd -rpcwallet=peerswap1 rescanblockchain
  MNEMONIC2="abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
  docker exec lnd_lwk-lwk2-1 lwk_cli --network=regtest --addr=127.0.0.1:32114 signer load-software --signer s2 --mnemonic "$MNEMONIC2" --persist true
  DESCRIPTOR=$(lwk2 signer singlesig-desc --signer s2 --descriptor-blinding-key slip77 --kind wpkh | jq -r .descriptor)
  lwk2 wallet load --wallet w2 -d "$DESCRIPTOR"
  ADDRESS2=$(lwk2 wallet address --wallet w2 | jq -r .address)
  elementsd -rpcwallet=peerswap1 sendtoaddress $ADDRESS2 1
  elementsd -rpcwallet=peerswap1 -generate 3
  elementsd -rpcwallet=peerswap1 rescanblockchain
  MNEMONIC3="cheese clarify antique vehicle custom absurd identify abuse cheap fix jeans frozen"
  docker exec lnd_lwk-lwk-1 lwk_cli --network=regtest --addr=127.0.0.1:32113 signer load-software --signer s3 --mnemonic "$MNEMONIC3" --persist true
  DESCRIPTOR=$(lwk signer singlesig-desc --signer s3 --descriptor-blinding-key slip77 --kind wpkh | jq -r .descriptor)
  lwk wallet load --wallet w3 -d "$DESCRIPTOR"
  ADDRESS3=$(lwk wallet address --wallet w3 | jq -r .address)
  elementsd -rpcwallet=peerswap1 sendtoaddress $ADDRESS3 1
  elementsd -rpcwallet=peerswap1 -generate 3
  elementsd -rpcwallet=peerswap1 rescanblockchain
}

mineBlocks() {
  ADDRESS=$1
  AMOUNT=${2:-1}
  echo Mining $AMOUNT blocks to $ADDRESS...
  bitcoind generatetoaddress $AMOUNT $ADDRESS
  sleep 0.5 # waiting for blocks to be propagated
}

initBitcoinChain() {
  # Mine 103 blocks to initliase a bitcoind node.
  mineBlocks $BITCOIN_ADDRESS 103
}

generateAddresses() {
  BITCOIN_ADDRESS=$(bitcoind getnewaddress)
  echo BITCOIN_ADDRESS: $BITCOIN_ADDRESS

  LND1_ADDRESS=$(lnd1 newaddress p2wkh | jq -r .address)
  echo LND1_ADDRESS: $LND1_ADDRESS

  LND2_ADDRESS=$(lnd2 newaddress p2wkh | jq -r .address)
  echo LND2_ADDRESS: $LND2_ADDRESS

  CLN1_ADDRESS=$(cln1 newaddr | jq -r .bech32)
  echo CLN1_ADDRESS: $CLN1_ADDRESS
}

getNodeInfo() {
  LND1_NODE_INFO=$(lnd1 getinfo)
  LND1_NODE_URI=$(echo ${LND1_NODE_INFO} | jq -r '.uris[0]')
  echo LND1_NODE_URI: $LND1_NODE_URI

  LND1_PUBKEY=$(echo ${LND1_NODE_INFO} | jq -r .identity_pubkey)
  echo LND1_PUBKEY: $LND1_PUBKEY

  LND2_NODE_INFO=$(lnd2 getinfo)
  LND2_NODE_URI=$(echo ${LND2_NODE_INFO} | jq -r '.uris[0]')
  echo LND2_NODE_URI: $LND2_NODE_URI

  LND2_PUBKEY=$(echo ${LND2_NODE_INFO} | jq -r .identity_pubkey)
  echo LND2_PUBKEY: $LND2_PUBKEY

  CLN1_NODE_INFO=$(cln1 getinfo)
  CLN1_NODE_URI=$(echo ${CLN1_NODE_INFO} | jq -r .id)@172.32.1.7:19846
  echo CLN1_NODE_URI: $CLN1_NODE_URI

  CLN1_PUBKEY=$(echo ${CLN1_NODE_INFO} | jq -r .id)
  echo CLN1_PUBKEY: $CLN1_PUBKEY
}

sendFundingTransaction() {
  echo creating raw tx...
  local addresses=($LND1_ADDRESS $LND2_ADDRESS $CLN1_ADDRESS)
  local outputs=$(jq -nc --arg amount 1 '$ARGS.positional | reduce .[] as $address ({}; . + {($address) : ($amount | tonumber)})' --args "${addresses[@]}")
  RAW_TX=$(bitcoind createrawtransaction "[]" $outputs)
  echo RAW_TX: $RAW_TX

  echo funding raw tx $RAW_TX...
  FUNDED_RAW_TX=$(bitcoind fundrawtransaction "$RAW_TX" | jq -r '.hex')
  echo FUNDED_RAW_TX: $FUNDED_RAW_TX

  echo signing funded tx $FUNDED_RAW_TX...
  SIGNED_TX_HEX=$(bitcoind signrawtransactionwithwallet "$FUNDED_RAW_TX" | jq -r '.hex')
  echo SIGNED_TX_HEX: $SIGNED_TX_HEX

  echo sending signed tx $SIGNED_TX_HEX...
  bitcoind sendrawtransaction "$SIGNED_TX_HEX"
}

fundNodes() {
  # Fund with multiple transactions to that we have multiple utxos to spend on each of the lnd nodes.
  sendFundingTransaction
  sendFundingTransaction
  sendFundingTransaction

  # Generate some blocks to confirm the transactions.
  mineBlocks $BITCOIN_ADDRESS 6

  sleep 30
  # Open a channel between the two nodes.
  waitFor cln1 connect $LND2_NODE_URI || true
  waitFor cln1 fundchannel $LND2_PUBKEY 100000000

  # Generate some blocks to confirm the channel.
  mineBlocks $BITCOIN_ADDRESS 6
}

openChannel() {
  # Open a channel between the two nodes.
  waitFor lnd1 connect $LND2_NODE_URI || true
  waitFor lnd1 openchannel $LND2_PUBKEY 100000000

  # Generate some blocks to confirm the channel.
  mineBlocks $BITCOIN_ADDRESS 6
}

waitForNodes() {
  waitFor bitcoind getnetworkinfo
  waitFor lnd1 getinfo
  waitFor lnd2 getinfo
  waitFor cln1 getinfo
}


main() {
  createBitcoindWallet
  createElementsWallet
  createLWKWallet
  waitForNodes
  generateAddresses
  getNodeInfo
  initBitcoinChain
  fundNodes
  openChannel
}

main

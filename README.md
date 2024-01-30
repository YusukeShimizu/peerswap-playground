# Peerswap Playground

This PeerSwap Playground provides a docker stack that comprises bitcoind, elementsd, 2x lnd nodes and 2x peerswap clients. It connects everything together, initializes the wallets, and creates a channel between the two nodes.

You can use this to get familiar with [Peerswaps](https://www.peerswap.dev/).

## Usage
**Start nodes:**

```sh
docker compose up
```

**Initialise the nodes:**

```sh
./scripts/init.sh
```

**Clean everything:**
```sh
docker compose down --volumes
```

### LND Usage

**Get the pubkey of one of the nodes:**

```sh
PUBKEY=$(./bin/lncli lnd2 getinfo  | jq -r '.identity_pubkey')
```

**Get details of channel connecting the nodes:**

```sh
CHANID=$(./bin/lncli lnd1 listchannels | jq -r --arg pubkey "$PUBKEY" '.channels[] | select(.remote_pubkey == $pubkey) | .chan_id')
```

```sh
CLNSHORTCHANID=$(./bin/clncli listfunds | jq -r --arg pubkey "$PUBKEY" '.channels[] | select(.peer_id == $pubkey) | .short_channel_id')
```

**Initiate a swapout:**

```sh
./bin/pscli peerswap1 swapout --channel_id $CHANID --sat_amt 1000000 --asset lbtc --premium_limit 1000000
```

**Mine 3 blocks on the Liquid network:**

```sh
./bin/elements-cli -rpcwallet=peerswap1 -generate 3
```

**Wait ~10 seconds...**	

```sh
sleep 10
```

**Track progress:**

```sh
./bin/pscli peerswap1 listswaps
./bin/pscli peerswap2 listswaps
./bin/clncli peerswap-listswaps
```

**Check liquid balances:**

```sh
./bin/pscli peerswap1 lbtc-getbalance
./bin/pscli peerswap2 lbtc-getbalance
./bin/clncli peerswap-lbtc-getbalance
```

**Check channel balance:**

```sh
./bin/lncli lnd1 listchannels | grep -A 3 $CHANID
./bin/lncli lnd2 listchannels | grep -A 3 $CHANID
./bin/clncli listpeerchannels | grep -A 30 $CLNCHANID
```

### CLN Usage

**Get the pubkey of one of the nodes:**

```sh
PUBKEY=$(./bin/lncli lnd2 getinfo  | jq -r '.identity_pubkey')
```

**Get details of channel connecting the nodes:**
```sh
CLNSHORTCHANID=$(./bin/clncli listfunds | jq -r --arg pubkey "$PUBKEY" '.channels[] | select(.peer_id == $pubkey) | .short_channel_id')
```

**Initiate a swapout:**

```sh
./bin/pscli peerswap1 swapout --channel_id $CHANID --sat_amt 1000000 --asset lbtc --premium_limit 1000000
```

**Mine 3 blocks on the Liquid network:**

```sh
./bin/elements-cli -rpcwallet=cln1 -generate 3
```

**Wait ~10 seconds...**	

```sh
sleep 10
```

**Track progress:**

```sh
./bin/pscli peerswap2 listswaps
./bin/clncli peerswap-listswaps
```

**Check liquid balances:**

```sh
./bin/pscli peerswap2 lbtc-getbalance
./bin/clncli peerswap-lbtc-getbalance
```

**Check channel balance:**

```sh
./bin/lncli lnd2 listchannels | grep -A 3 $CHANID
./bin/clncli listpeerchannels | grep -A 30 $CLNCHANID
```
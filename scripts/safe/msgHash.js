const { Contract, JsonRpcProvider } = require("ethers")

if (!process.env.SAFE || !process.env.MSG) {
  throw Error("must set env var SAFE=0x... and MSG=0x...")
}

async function main() {
  const safe = new Contract(
    process.env.SAFE,
    [
      "function getMessageHash(bytes memory message) public view returns (bytes32)"
    ],
    {
      provider: new JsonRpcProvider(
        process.env.RPC ?? "https://rpc.gnosis.gateway.fm"
      )
    }
  )

  const msgHash = await safe.getMessageHash(
    Buffer.from(process.env.MSG, "utf8")
  )

  console.log("msgHash", msgHash)
}

main()
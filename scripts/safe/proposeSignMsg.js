const { default: Safe, EthersAdapter } = require("@safe-global/protocol-kit")
const { default: SafeApiKit } = require("@safe-global/api-kit")
const ethers = require("ethers")

const SIGN_MSG_LIB = "0xd53cd0aB83D845Ac265BE939c57F53AD838012c9"

if (!process.env.SAFE || !process.env.MSG || !process.env.PRIVATE_KEY) {
  throw Error("must set env var SAFE=0x... PRIVATE_KEY=0x... and MSG=abcd...")
}

async function main() {
  const provider = new ethers.JsonRpcProvider(
    process.env.RPC ?? "https://rpc.gnosis.gateway.fm"
  )

  const signer = new ethers.Wallet(process.env.PRIVATE_KEY, provider)

  const ethAdapter = new EthersAdapter({
    ethers,
    signerOrProvider: signer
  })

  const safeSigner = await Safe.create({
    ethAdapter,
    safeAddress: process.env.SAFE
  })
  const rawData = new ethers.Interface([
    "function signMessage(bytes calldata _data)"
  ]).encodeFunctionData("signMessage", [Buffer.from(process.env.MSG, "utf8")])
  const safeTransactionData = {
    to: SIGN_MSG_LIB,
    data: rawData,
    operation: 1, // delegateCall
    value: "0"
  }
  const safeTx = await safeSigner.createTransaction({
    transactions: [safeTransactionData]
  })

  const apiKit = new SafeApiKit({
    chainId: 100
  })

  // Deterministic hash based on transaction parameters
  const safeTxHash = await safeSigner.getTransactionHash(safeTx)

  // Sign transaction to verify that the transaction is coming from owner 1
  const senderSignature = await safeSigner.signHash(safeTxHash)

  await apiKit.proposeTransaction({
    safeAddress: process.env.SAFE,
    safeTransactionData: safeTx.data,
    safeTxHash,
    senderAddress: signer.address, //await owner1Signer.getAddress(),
    senderSignature: senderSignature.data
  })

  console.log(
    `proposed: Safe ---delegatecall---> SignMessageLib.signMessage("${process.env.MSG}")`
  )
  console.log("safe tx hash", safeTxHash)
}

main()
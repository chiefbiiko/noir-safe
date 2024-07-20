import { compile, createFileManager } from '@noir-lang/noir_wasm';
import { BarretenbergBackend } from '@noir-lang/backend_barretenberg';
import { Noir } from "@noir-lang/noir_js"
import { join } from "path"
import { cpus } from 'os'

const threads = cpus()

const spPath = join(import.meta.dirname, "../..", "circuits/storage-proof")
const apPath = join(import.meta.dirname, "../..", "circuits/account-proof")
const anchorPath = join(import.meta.dirname, "../..", "circuits/anchor")

const spMeta = await compile(createFileManager(spPath));
const apMeta = await compile(createFileManager(apPath));

if (!spMeta.program) {
  throw new Error('Storage proof shard compilation failed');
}
if (!apMeta.program) {
  throw new Error('Account proof shard compilation failed');
}

const spBackend = new BarretenbergBackend(spMeta.program, { threads })
const apBackend = new BarretenbergBackend(apMeta.program, { threads })
//WIP
const spNoir = new Noir(spMeta.program, spBackend)
const { witness: spWitness } = spNoir.execute({
    storage_root: "TODO",
    storage_key: "TODO",
    storage_proof_depth: "TODO",
    storage_proof: "TODO",
})
const apNoir = new Noir(apMeta.program, apBackend)
const { witness: apWitness } = apNoir.execute({
    safe_address: "TODO",
    state_root: "TODO",
    account_proof_depth: "TODO",
    padded_account_value: "TODO",
    account_proof: "TODO",
})

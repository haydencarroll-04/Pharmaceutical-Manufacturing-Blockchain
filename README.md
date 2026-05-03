## PharmaChain

A Solidity smart contract for pharmaceutical supply chain management on the Ethereum blockchain. Built as a class project exploring blockchain applications in healthcare and pharmaceutical manufacturing. Utilized Claude Code to help create this smart contract..

---

## Overview

PharmaChain creates a tamper-evident, end-to-end record of a drug batch's journey from manufacturer to patient. Every registration, transfer, and recall is written permanently to the blockchain — no single party can alter or delete a record after the fact.

This project is grounded in the **Build-Own-Operate-Transfer (BOOT)** governance model: a founding manufacturer deploys and controls the contract, with the intent to transfer ownership to an industry consortium once the network proves its value.

---

## The Problem It Solves

The pharmaceutical supply chain faces serious risks:

- **Drug tampering** — counterfeit or contaminated products entering the chain
- **Drug trafficking** — unauthorized diversion between distribution points
- **Recall failures** — inability to quickly isolate a specific batch across a large network
- **Lack of transparency** — no single source of truth shared across manufacturers, distributors, pharmacies, and regulators

PharmaChain addresses all four with immutable, on-chain records.

---

## Core Functions

### 1. `registerDrug(drugName, batchId, expiryDate)`
Called by an authorized manufacturer to record a new drug batch on-chain at the point of production. Establishes tamper-evident proof of origin, composition, and expiry.

### 2. `transferCustody(batchId, to, newStage)`
Moves a batch to the next stage of the supply chain (Manufactured → InTransit → AtDistributor → AtPharmacy → Dispensed). Each handoff is logged as an immutable event. Automatically reverts if the batch has been recalled or is expired.

### 3. `recallBatch(batchId, reason)`
Flags a batch as recalled with a plaintext reason. Any subsequent `transferCustody` call on a recalled batch will revert, instantly halting its movement through the entire chain.

---

## Supply Chain Stages

| Value | Stage |
|-------|-------|
| `0` | Manufactured |
| `1` | InTransit |
| `2` | AtDistributor |
| `3` | AtPharmacy |
| `4` | Dispensed |

---

## Getting Started

### Prerequisites
- A web browser
- No installs required — Remix IDE runs entirely in the browser

### Deploy in Remix

1. Open [https://remix.ethereum.org](https://remix.ethereum.org)
2. In the **File Explorer**, create a new file: `PharmaChain.sol`
3. Paste in the contract source code
4. Open the **Solidity Compiler** tab → select version `0.8.20` or later → click **Compile PharmaChain.sol**
5. Open the **Deploy & Run Transactions** tab → set Environment to `Remix VM (Cancun)` → click **Deploy********

---
******
## Usage

### Register a drug batch
registerDrug("Amoxicillin 500mg", "BATCH-001", 2000000000)

### Transfer custody to a distributor
transferCustody("BATCH-001", 0xABC...123, 1)

### Recall a batch
recallBatch("BATCH-001", "Contamination detected in lot")

### Look up a batch
getBatch("BATCH-001")

### Quick test sequence
registerDrug("Amoxicillin 500mg", "BATCH-001", 2000000000)
getBatch("BATCH-001") // stage = 0
transferCustody("BATCH-001", <addr2>, 1)
getBatch("BATCH-001") // stage = 1
recallBatch("BATCH-001", "Contamination found")
transferCustody("BATCH-001", <addr3>, 2) // REVERTS


---

## Access Control

| Role | Permissions |
|------|-------------|
| Owner (deployer) | Add manufacturers, add distributors, transfer to consortium |
| Authorized Manufacturer | Register drugs, transfer custody, recall batches |
| Authorized Distributor | Transfer custody, recall batches |
| Consortium | Governance after BOOT transfer |

---

## Events

| Event | Fired when |
|-------|------------|
| `DrugRegistered` | A new batch is registered |
| `CustodyTransferred` | A batch moves to a new stage |
| `BatchRecalled` | A batch is flagged as recalled |
| `OwnershipTransferredToConsortium` | Governance is handed to the industry |

---

## BOOT Model

This contract implements the **Build-Own-Operate-Transfer** governance model:

1. **Build** — A founding manufacturer deploys the contract and funds initial development
2. **Own & Operate** — The owner authorizes participants and maintains the permissioned network
3. **Transfer** — Once the network proves its value, `transferToConsortium()` hands governance to an industry body, spreading cost and responsibility across all stakeholders

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Smart Contract | Solidity `^0.8.20` |
| Blockchain | Ethereum (EVM-compatible) |
| Development Environment | Remix IDE |
| Test Network | Remix VM (Cancun) |

---

## Limitations & Future Work

- **Off-chain data** — Drug composition details and clinical trial records would need a companion system (e.g., IPFS) to store large documents linked by hash
- **Oracle integration** — Real-world events (FDA approvals, lab test results) would require a trusted oracle such as Chainlink
- **HIPAA / GDPR compliance** — Patient-level data must remain off-chain; this contract handles batch-level logistics only
- **Gas optimization** — String storage is expensive; a production version would use `bytes32` for batch IDs

---

## License

MIT

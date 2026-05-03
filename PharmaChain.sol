// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PharmaChain
 * @notice Pharmaceutical supply chain tracker built on the BOOT model.
 *         A single founding manufacturer deploys and owns the contract,
 *         with the intent to transfer governance to an industry consortium.
 *
 * Three core functions (per BOOT model paper):
 *   1. registerDrug     – manufacturer registers a new drug batch
 *   2. transferCustody  – moves custody along the supply chain
 *   3. recallBatch      – flags a batch as recalled for safety/tampering
 */
contract PharmaChain {

    // ─── Roles ────────────────────────────────────────────────────────────────

    address public owner;           // founding entity (BOOT model)
    address public consortium;      // industry group after transfer
    bool    public transferred;     // whether ownership has been handed off

    mapping(address => bool) public authorizedManufacturers;
    mapping(address => bool) public authorizedDistributors;

    // ─── Data structures ──────────────────────────────────────────────────────

    enum CustodyStage {
        Manufactured,   // 0
        InTransit,      // 1
        AtDistributor,  // 2
        AtPharmacy,     // 3
        Dispensed       // 4
    }

    struct DrugBatch {
        string  drugName;
        string  batchId;
        address manufacturer;
        uint256 manufactureDate;    // Unix timestamp
        uint256 expiryDate;         // Unix timestamp
        CustodyStage stage;
        address currentCustodian;
        bool    recalled;
        string  recallReason;
    }

    // batchId (string) → DrugBatch
    mapping(string => DrugBatch) private batches;
    // Track all registered batch IDs for enumeration
    string[] public allBatchIds;

    // ─── Events ───────────────────────────────────────────────────────────────

    event DrugRegistered(
        string indexed batchId,
        string drugName,
        address indexed manufacturer,
        uint256 expiryDate
    );

    event CustodyTransferred(
        string indexed batchId,
        address indexed from,
        address indexed to,
        CustodyStage newStage
    );

    event BatchRecalled(
        string indexed batchId,
        string drugName,
        string reason,
        uint256 timestamp
    );

    event OwnershipTransferredToConsortium(
        address indexed previousOwner,
        address indexed consortium
    );

    // ─── Modifiers ────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedManufacturers[msg.sender] ||
            authorizedDistributors[msg.sender] ||
            msg.sender == owner ||
            msg.sender == consortium,
            "Not an authorized supply chain participant"
        );
        _;
    }

    modifier batchExists(string memory batchId) {
        require(batches[batchId].manufactureDate != 0, "Batch does not exist");
        _;
    }

    modifier notRecalled(string memory batchId) {
        require(!batches[batchId].recalled, "Batch has been recalled");
        _;
    }

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
        authorizedManufacturers[msg.sender] = true;
    }

    // ─── Admin: authorize participants ────────────────────────────────────────

    function addManufacturer(address account) external onlyOwner {
        authorizedManufacturers[account] = true;
    }

    function addDistributor(address account) external onlyOwner {
        authorizedDistributors[account] = true;
    }

    // ─── BOOT model: transfer governance to consortium ────────────────────────

    function transferToConsortium(address _consortium) external onlyOwner {
        require(!transferred, "Already transferred");
        require(_consortium != address(0), "Invalid address");
        consortium = _consortium;
        transferred = true;
        emit OwnershipTransferredToConsortium(owner, _consortium);
    }

    // =========================================================================
    //  FUNCTION 1 — registerDrug
    //  Manufacturer records a new drug batch on-chain at point of production.
    //  Provides tamper-evident proof of origin, composition, and expiry.
    // =========================================================================

    /**
     * @param drugName   Human-readable drug name (e.g. "Amoxicillin 500mg")
     * @param batchId    Unique batch/lot identifier from manufacturing system
     * @param expiryDate Unix timestamp of expiry date
     */
    function registerDrug(
        string calldata drugName,
        string calldata batchId,
        uint256 expiryDate
    ) external {
        require(authorizedManufacturers[msg.sender], "Only manufacturers can register");
        require(batches[batchId].manufactureDate == 0, "Batch ID already registered");
        require(expiryDate > block.timestamp, "Expiry date must be in the future");
        require(bytes(drugName).length > 0, "Drug name cannot be empty");
        require(bytes(batchId).length > 0,  "Batch ID cannot be empty");

        batches[batchId] = DrugBatch({
            drugName:         drugName,
            batchId:          batchId,
            manufacturer:     msg.sender,
            manufactureDate:  block.timestamp,
            expiryDate:       expiryDate,
            stage:            CustodyStage.Manufactured,
            currentCustodian: msg.sender,
            recalled:         false,
            recallReason:     ""
        });

        allBatchIds.push(batchId);

        emit DrugRegistered(batchId, drugName, msg.sender, expiryDate);
    }

    // =========================================================================
    //  FUNCTION 2 — transferCustody
    //  Moves a batch to the next stage of the supply chain.
    //  Creates an immutable audit trail that deters drug trafficking and
    //  allows regulators to pinpoint exactly where a breach occurred.
    // =========================================================================

    /**
     * @param batchId   The batch being moved
     * @param to        Address of the receiving party (distributor / pharmacy)
     * @param newStage  The custody stage the batch is entering
     */
    function transferCustody(
        string calldata batchId,
        address to,
        CustodyStage newStage
    )
        external
        onlyAuthorized
        batchExists(batchId)
        notRecalled(batchId)
    {
        DrugBatch storage batch = batches[batchId];

        require(
            msg.sender == batch.currentCustodian,
            "Only current custodian can transfer"
        );
        require(to != address(0), "Recipient cannot be zero address");
        require(
            uint8(newStage) == uint8(batch.stage) + 1,
            "Must advance exactly one stage"
        );
        require(
            block.timestamp < batch.expiryDate,
            "Cannot transfer an expired batch"
        );

        address previous = batch.currentCustodian;
        batch.currentCustodian = to;
        batch.stage = newStage;

        emit CustodyTransferred(batchId, previous, to, newStage);
    }

    // =========================================================================
    //  FUNCTION 3 — recallBatch
    //  Flags a batch as recalled with a stated reason.
    //  Any subsequent transferCustody call on a recalled batch will revert,
    //  halting its movement through the chain immediately and permanently.
    // =========================================================================

    /**
     * @param batchId  The batch to recall
     * @param reason   Plain-text reason (e.g. "Contamination detected in lot")
     */
    function recallBatch(
        string calldata batchId,
        string calldata reason
    )
        external
        onlyAuthorized
        batchExists(batchId)
    {
        DrugBatch storage batch = batches[batchId];
        require(!batch.recalled, "Batch already recalled");
        require(bytes(reason).length > 0, "Recall reason required");

        batch.recalled     = true;
        batch.recallReason = reason;

        emit BatchRecalled(batchId, batch.drugName, reason, block.timestamp);
    }

    // ─── Read helpers ─────────────────────────────────────────────────────────

    function getBatch(string calldata batchId)
        external
        view
        batchExists(batchId)
        returns (DrugBatch memory)
    {
        return batches[batchId];
    }

    function totalBatches() external view returns (uint256) {
        return allBatchIds.length;
    }
}

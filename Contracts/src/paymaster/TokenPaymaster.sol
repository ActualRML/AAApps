// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@account-abstraction/contracts/interfaces/IPaymaster.sol";
import "@account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../token/MockToken.sol";
import "../events/Events.sol" as Ev;

/**
 * @title TokenPaymaster
 * @notice Menangani pembayaran gas menggunakan MockToken dengan kurs real-time dari Oracle Chainlink.
 */
contract TokenPaymaster is IPaymaster, Ownable, Ev.Events {
    MockToken public immutable gasToken;
    IEntryPoint public immutable entryPoint;
    AggregatorV3Interface internal immutable priceFeed;

    uint256 public gasMarkup = 110; // 110 = 10% profit/buffer
    uint256 public constant PAYMASTER_OVERHEAD = 21000;

    constructor(
        address _gasToken, 
        address _entryPoint, 
        address _priceFeed,
        address _initialOwner
    ) Ownable(_initialOwner) {
        gasToken = MockToken(_gasToken);
        entryPoint = IEntryPoint(_entryPoint);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    /// @notice Update persentase markup (hanya admin)
    function setGasMarkup(uint256 _newMarkup) external onlyOwner {
        require(_newMarkup >= 100, "Markup too low");
        gasMarkup = _newMarkup;
    }

    /**
     * @notice Mendapatkan harga ETH terbaru dalam unit Token.
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");
        return uint256(price) * 1e10;
    }

    /**
     * @dev Validasi User Operation oleh EntryPoint.
     * FIX: Hapus 'view' karena kita melakukan 'transferFrom' (Pre-charge).
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Only EntryPoint");

        uint256 currentPrice = getLatestPrice();
        // 1. Hitung biaya MAKSIMAL yang mungkin terjadi (Pre-charge amount)
        uint256 maxTokenCost = (maxCost * currentPrice * gasMarkup) / (100 * 1e18);

        // 2. Cek saldo dan allowance (untuk pesan error yang jelas)
        require(gasToken.balanceOf(userOp.sender) >= maxTokenCost, "Low token balance");
        require(gasToken.allowance(userOp.sender, address(this)) >= maxTokenCost, "Low token allowance");

        // 3. TARIK TOKEN DI DEPAN
        // Dengan ini, Paymaster aman meskipun user nguras saldonya saat eksekusi.
        bool success = gasToken.transferFrom(userOp.sender, address(this), maxTokenCost);
        require(success, "Pre-charge failed");

        // 4. Kirim info user dan jumlah ditarik ke postOp via context untuk refund
        return (abi.encode(userOp.sender, maxTokenCost), 0);
    }

    /**
     * @dev Penarikan token final atau pengembalian sisa (Refund).
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external override {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        
        // Dekode context dari validatePaymasterUserOp
        (address user, uint256 preChargedAmount) = abi.decode(context, (address, uint256));

        // Jika mode adalah postOpReverted, EntryPoint akan mengabaikan perubahan state postOp,
        // Tapi kita tetap punya token user dari tahap validasi.
        if (mode == PostOpMode.postOpReverted) return;

        uint256 currentPrice = getLatestPrice();
        // 5. Hitung biaya ASLI yang terpakai
        uint256 actualTokenCost = (actualGasCost * currentPrice * gasMarkup) / (100 * 1e18);

        // 6. REFUND: Jika pre-charge > biaya asli, balikin sisanya ke user.
        if (preChargedAmount > actualTokenCost) {
            uint256 refundAmount = preChargedAmount - actualTokenCost;
            // Kita pakai transfer biasa karena token sudah ada di tangan Paymaster
            gasToken.transfer(user, refundAmount);
        }

        emit Ev.Events.Executed(address(this), user, actualTokenCost, "Paymaster Charge", 0);
    }

    // --- Fungsi Admin & Saldo (Tetap Sama) ---

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdrawToken(address to, uint256 amount) external onlyOwner {
        require(gasToken.transfer(to, amount), "Transfer failed");
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
    }

    receive() external payable {
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(address(this));
        }
    }
}
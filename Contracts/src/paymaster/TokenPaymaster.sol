// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
     * Mengasumsikan Oracle 8 desimal dan Token 18 desimal.
     */
    function getLatestPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price data");
        // Normalisasi desimal: 8 desimal -> 18 desimal (dikali 1e10)
        return uint256(price) * 1e10;
    }

    /**
     * @dev Validasi User Operation oleh EntryPoint.
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCost
    ) external override view returns (bytes memory context, uint256 validationData) {
        require(msg.sender == address(entryPoint), "Only EntryPoint");

        uint256 currentPrice = getLatestPrice();
        // Estimasi token yang dibutuhkan (maxCost dalam WEI * price)
        uint256 maxTokenCost = (maxCost * currentPrice * gasMarkup) / (100 * 1e18);

        // Cek saldo dan allowance user
        require(gasToken.balanceOf(userOp.sender) >= maxTokenCost, "Low token balance");
        require(gasToken.allowance(userOp.sender, address(this)) >= maxTokenCost, "Low token allowance");

        // Kirim alamat user ke postOp via context
        return (abi.encode(userOp.sender), 0);
    }

    /**
     * @dev Penarikan token dilakukan SETELAH transaksi sukses.
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external override {
        require(msg.sender == address(entryPoint), "Only EntryPoint");
        
        // Jika transaksi user revert total, kita tidak narik token (tergantung policy)
        if (mode == PostOpMode.postOpReverted) return;

        address user = abi.decode(context, (address));
        uint256 currentPrice = getLatestPrice();

        // actualGasCost sudah dalam WEI (ETH)
        uint256 tokenAmountToCharge = (actualGasCost * currentPrice * gasMarkup) / (100 * 1e18);

        // Tarik token dari user ke paymaster
        bool success = gasToken.transferFrom(user, address(this), tokenAmountToCharge);
        require(success, "Token payment failed");

        emit Ev.Events.Executed(address(this), user, tokenAmountToCharge, "Paymaster Charge", 0);
    }

    // --- Fungsi Admin & Saldo ---

    /**
     * @notice Setor ETH ke EntryPoint agar Paymaster punya saldo untuk bayar gas user.
     */
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    function withdrawToken(address to, uint256 amount) external onlyOwner {
        require(gasToken.transfer(to, amount), "Transfer failed");
    }

    function withdrawETH(address payable to, uint256 amount) external onlyOwner {
        // Tarik dari deposit EntryPoint
        entryPoint.withdrawTo(to, amount);
    }

    receive() external payable {
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(address(this));
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "@account-abstraction/interfaces/PackedUserOperation.sol";

import {MockToken} from "../token/MockToken.sol";
import {Errors} from "../common/Errors.sol";
import "../common/Events.sol" as Ev;

/**
 * @title TokenPaymaster
 * @notice Versi Upgradeable/Proxy-ready. Bayar gas pake MockToken via Oracle Chainlink.
 * @dev Fee markup otomatis tersimpan di saldo gasToken kontrak ini.
 */
contract TokenPaymaster is Initializable, OwnableUpgradeable, IPaymaster, Ev.Events {
    // Variabel storage untuk Proxy
    MockToken public gasToken;
    IEntryPoint public entryPoint;
    AggregatorV3Interface internal priceFeed;

    uint256 public gasMarkup; 
    uint256 public constant PAYMASTER_OVERHEAD = 21000;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); 
    }

    /**
     * @notice Pengganti constructor untuk pola Proxy
     */
    function initialize(
        address _gasToken, 
        address _entryPoint, 
        address _priceFeed,
        address _initialOwner
    ) public initializer {
        __Ownable_init(_initialOwner); 
        
        gasToken = MockToken(_gasToken);
        entryPoint = IEntryPoint(_entryPoint);
        priceFeed = AggregatorV3Interface(_priceFeed);
        gasMarkup = 110; // Default 10% fee markup
    }

    // ============ CONFIGURATION ============

    function setGasMarkup(uint256 _newMarkup) external onlyOwner {
        if (_newMarkup < 100) revert Errors.MarkupTooLow();
        gasMarkup = _newMarkup;
    }

    /**
     * @notice Ambil harga token vs ETH dari Chainlink (8 decimals -> 18 decimals)
     */
    function getLatestPrice() public view returns (uint256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        
        // Fix warning [unsafe-typecast]: Check sebelum cast ke uint256
        if (price <= 0) revert Errors.InvalidPriceData();

        // forge-lint: disable-next-line(unsafe-typecast)
        return uint256(price) * 1e10; 
    }

    // ============ ERC-4337 CORE ============

    /**
     * @dev Validasi User Op: Pre-charge token dari wallet user ke Paymaster.
     */
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 maxCost
    ) external override returns (bytes memory context, uint256 validationData) {
        if (msg.sender != address(entryPoint)) revert Errors.NotEntryPoint();

        uint256 currentPrice = getLatestPrice();
        // Rumus: (ETH_Cost * Token_Price * Markup) / Scaler
        uint256 maxTokenCost = (maxCost * currentPrice * gasMarkup) / (100 * 1e18);

        // Pre-charge: Cek return value transferFrom (Fix warning erc20-unchecked-transfer)
        if (!gasToken.transferFrom(userOp.sender, address(this), maxTokenCost)) {
            revert Errors.PreChargeFailed();
        }

        return (abi.encode(userOp.sender, maxTokenCost), 0);
    }

    /**
     * @dev postOp: Hitung biaya asli dan kasih Refund sisa token ke user.
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 /*actualUserOpFeePerGas*/
    ) external override {
        if (msg.sender != address(entryPoint)) revert Errors.NotEntryPoint();
        
        (address user, uint256 preChargedAmount) = abi.decode(context, (address, uint256));

        if (mode == PostOpMode.postOpReverted) return;

        uint256 currentPrice = getLatestPrice();
        uint256 actualTokenCost = (actualGasCost * currentPrice * gasMarkup) / (100 * 1e18);

        if (preChargedAmount > actualTokenCost) {
            unchecked {
                uint256 refundAmount = preChargedAmount - actualTokenCost;
                // Fix warning erc20-unchecked-transfer
                if (!gasToken.transfer(user, refundAmount)) revert Errors.TransferFailed();
            }
        }

        emit Ev.Events.PaymasterCharge(address(this), user, actualTokenCost, "Gas Fee + Markup");
    }

    // ============ ADMIN & FEE MANAGEMENT ============

    function getInternalBalance() external view returns (uint256) {
        return gasToken.balanceOf(address(this));
    }

    function withdrawToken(address to, uint256 amount) external onlyOwner {
        if (!gasToken.transfer(to, amount)) revert Errors.WithdrawFailed();
    }

    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    /**
     * @notice Fix note [mixed-case-function]: ETH -> Eth
     */
    function withdrawEth(address payable to, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(to, amount);
    }

    receive() external payable {
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(address(this));
        }
    }
}
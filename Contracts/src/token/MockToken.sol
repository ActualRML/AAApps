// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Events} from "../common/Events.sol";
import {Errors} from "../common/Errors.sol";

contract MockToken is ERC20, Events {
    address public owner;

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (msg.sender != owner) revert Errors.NotOwner(); 
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address _owner
    ) ERC20(name, symbol) {
        owner = _owner;
        if (initialSupply > 0) {
            _mint(_owner, initialSupply);
        }
        // Emit event saat token pertama kali dibuat (opsional tapi bagus buat indexing)
        emit TokenCreated(address(this), name, symbol, _owner);
    }

    /**
     * @notice Cetak token baru. Hanya Owner yang bisa.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokenMinted(address(this), to, amount);
    }

    /**
     * @notice Hapus token dari saldo pengirim.
     */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        // Sekarang setiap burn bakal tercatat di log blockchain
        emit TokenBurned(address(this), msg.sender, amount);
    }

    /**
     * @notice Update owner kontrak jika diperlukan.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        // Kita bisa pakai event AccountCreated atau buat event khusus OwnerChanged di common
        owner = newOwner;
    }
}
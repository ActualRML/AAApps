// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Events} from "../events/Events.sol";

contract MockToken is ERC20, Events {
    address public owner;

    modifier onlyOwner() {
        if (msg.sender != owner) revert("Not owner");
        _;
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
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokenMinted(address(this), to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
export const ENTRY_POINT_ABI = [
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [
        { "name": "account", "type": "address", "internalType": "address" }
      ],
      "outputs": [
        { "name": "", "type": "uint256", "internalType": "uint256" }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "balances",
      "inputs": [
        { "name": "", "type": "address", "internalType": "address" }
      ],
      "outputs": [
        { "name": "", "type": "uint256", "internalType": "uint256" }
      ],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "depositTo",
      "inputs": [
        { "name": "account", "type": "address", "internalType": "address" }
      ],
      "outputs": [],
      "stateMutability": "payable"
    },
    {
      "type": "function",
      "name": "handleOps",
      "inputs": [
        { "name": "sender", "type": "address", "internalType": "address payable" },
        { "name": "target", "type": "address", "internalType": "address" },
        { "name": "value", "type": "uint256", "internalType": "uint256" },
        { "name": "data", "type": "bytes", "internalType": "bytes" },
        { "name": "nonce", "type": "uint256", "internalType": "uint256" },
        { "name": "signature", "type": "bytes", "internalType": "bytes" }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "withdrawTo",
      "inputs": [
        { "name": "to", "type": "address", "internalType": "address payable" },
        { "name": "amount", "type": "uint256", "internalType": "uint256" }
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "event",
      "name": "Deposited",
      "inputs": [
        { "name": "account", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "amount", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OpsExecuted",
      "inputs": [
        { "name": "sender", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "success", "type": "bool", "indexed": false, "internalType": "bool" },
        { "name": "result", "type": "bytes", "indexed": false, "internalType": "bytes" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Withdrawn",
      "inputs": [
        { "name": "account", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "to", "type": "address", "indexed": false, "internalType": "address" },
        { "name": "amount", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    }
  ] as const;
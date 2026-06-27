export const TOKEN_ABI = [
    {
      "type": "function",
      "name": "allTokens",
      "inputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
      "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "createToken",
      "inputs": [
        { "name": "name", "type": "string", "internalType": "string" },
        { "name": "symbol", "type": "string", "internalType": "string" },
        { "name": "initialSupply", "type": "uint256", "internalType": "uint256" }
      ],
      "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "getAllTokens",
      "inputs": [],
      "outputs": [{ "name": "", "type": "address[]", "internalType": "address[]" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getTokensCount",
      "inputs": [],
      "outputs": [{ "name": "", "type": "uint256", "internalType": "uint256" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "getTokensRange",
      "inputs": [
        { "name": "start", "type": "uint256", "internalType": "uint256" },
        { "name": "end", "type": "uint256", "internalType": "uint256" }
      ],
      "outputs": [{ "name": "", "type": "address[]", "internalType": "address[]" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "tokenByHash",
      "inputs": [{ "name": "", "type": "bytes32", "internalType": "bytes32" }],
      "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
      "stateMutability": "view"
    },
    {
      "type": "event",
      "name": "AccountCreated",
      "inputs": [
        { "name": "owner", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "account", "type": "address", "indexed": false, "internalType": "address" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Deposit",
      "inputs": [
        { "name": "sender", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "amount", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "Executed",
      "inputs": [
        { "name": "sender", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "target", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "value", "type": "uint256", "indexed": false, "internalType": "uint256" },
        { "name": "data", "type": "bytes", "indexed": false, "internalType": "bytes" },
        { "name": "nonce", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "OwnerChanged",
      "inputs": [
        { "name": "oldOwner", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "newOwner", "type": "address", "indexed": true, "internalType": "address" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "PaymasterCharge",
      "inputs": [
        { "name": "paymaster", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "user", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "tokenAmount", "type": "uint256", "indexed": false, "internalType": "uint256" },
        { "name": "reason", "type": "string", "indexed": false, "internalType": "string" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "TokenBurned",
      "inputs": [
        { "name": "token", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "from", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "amount", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "TokenCreated",
      "inputs": [
        { "name": "token", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "name", "type": "string", "indexed": false, "internalType": "string" },
        { "name": "symbol", "type": "string", "indexed": false, "internalType": "string" },
        { "name": "owner", "type": "address", "indexed": true, "internalType": "address" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "TokenMinted",
      "inputs": [
        { "name": "token", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "to", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "amount", "type": "uint256", "indexed": false, "internalType": "uint256" }
      ],
      "anonymous": false
    },
    {
      "type": "event",
      "name": "UserOperationExecuted",
      "inputs": [
        { "name": "sender", "type": "address", "indexed": true, "internalType": "address" },
        { "name": "nonce", "type": "uint256", "indexed": false, "internalType": "uint256" },
        { "name": "result", "type": "bytes", "indexed": false, "internalType": "bytes" }
      ],
      "anonymous": false
    }
  ] as const;
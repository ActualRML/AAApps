export const PAYMASTER_ABI = [
    {
      "type": "function",
      "name": "validatePaymasterUserOp",
      "inputs": [
        {
          "name": "userOp",
          "type": "tuple",
          "components": [
            { "name": "sender", "type": "address" },
            { "name": "nonce", "type": "uint256" },
            { "name": "initCode", "type": "bytes" },
            { "name": "callData", "type": "bytes" },
            { "name": "accountGasLimits", "type": "bytes32" },
            { "name": "preVerificationGas", "type": "uint256" },
            { "name": "gasFees", "type": "bytes32" },
            { "name": "paymasterAndData", "type": "bytes" },
            { "name": "signature", "type": "bytes" }
          ]
        },
        { "name": "", "type": "bytes32" },
        { "name": "maxCost", "type": "uint256" }
      ],
      "outputs": [
        { "name": "context", "type": "bytes" },
        { "name": "validationData", "type": "uint256" }
      ],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "getLatestPrice",
      "inputs": [],
      "outputs": [{ "name": "", "type": "uint256" }],
      "stateMutability": "view"
    },
    {
      "type": "event",
      "name": "PaymasterCharge",
      "inputs": [
        { "name": "paymaster", "type": "address", "indexed": true },
        { "name": "user", "type": "address", "indexed": true },
        { "name": "tokenAmount", "type": "uint256", "indexed": false },
        { "name": "reason", "type": "string", "indexed": false }
      ],
      "anonymous": false
    }
  ] as const;
export const SMART_ACCOUNT_ABI = [
    {
      "type": "function",
      "name": "owner",
      "inputs": [],
      "outputs": [{ "name": "", "type": "address" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "entryPoint",
      "inputs": [],
      "outputs": [{ "name": "", "type": "address" }],
      "stateMutability": "view"
    },
    {
      "type": "event",
      "name": "Executed",
      "inputs": [
        { "name": "sender", "type": "address", "indexed": true },
        { "name": "target", "type": "address", "indexed": true },
        { "name": "value", "type": "uint256", "indexed": false },
        { "name": "data", "type": "bytes", "indexed": false },
        { "name": "nonce", "type": "uint256", "indexed": false }
      ],
      "anonymous": false
    }
  ] as const;
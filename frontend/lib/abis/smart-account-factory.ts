export const SMART_ACCOUNT_FACTORY_ABI = [
    {
      "type": "function",
      "name": "createAccount",
      "inputs": [
        { "name": "owner", "type": "address", "internalType": "address" },
        { "name": "salt", "type": "uint256", "internalType": "uint256" }
      ],
      "outputs": [{ "name": "ret", "type": "address", "internalType": "address" }],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "getAddress",
      "inputs": [
        { "name": "owner", "type": "address", "internalType": "address" },
        { "name": "salt", "type": "uint256", "internalType": "uint256" }
      ],
      "outputs": [{ "name": "ret", "type": "address", "internalType": "address" }],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "accountImplementation",
      "inputs": [],
      "outputs": [{ "name": "", "type": "address", "internalType": "address" }],
      "stateMutability": "view"
    }
  ] as const;
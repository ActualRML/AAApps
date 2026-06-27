import { ENTRY_POINT_ABI } from './abis/entrypoint';
import { SMART_ACCOUNT_FACTORY_ABI } from './abis/smart-account-factory';
import { PAYMASTER_ABI } from './abis/paymaster';
import { SMART_ACCOUNT_ABI } from './abis/smart-account';
import { TOKEN_ABI } from './abis/token';

export const CONTRACTS = {
  ENTRYPOINT: {
    address: '0x08aAB491efE130f7760412c5708602A03d85feD0' as const,
    abi: ENTRY_POINT_ABI,
  },
  SMART_ACCOUNT_FACTORY: {
    address: '0x23d67D5b1F62A98601eE7A4bE7d69a2963b0a9Ad' as const,
    abi: SMART_ACCOUNT_FACTORY_ABI,
  },
  PAYMASTER: {
    address: '0xeCd6220145236CBA1a3e9bA47A53726b3F41D779' as const,
    abi: PAYMASTER_ABI,
  },
} as const;

export const SMART_ACCOUNT_CONFIG = {
  abi: SMART_ACCOUNT_ABI,
  implementation: '0x906BAaB4e50b156C8E9A0b7B5Be84E056ffB19b3' as const,
} as const;

export const TOKEN_CONFIG = {
  abi: TOKEN_ABI,
} as const;
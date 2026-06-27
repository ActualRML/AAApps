'use client';

import { useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/contracts';

export function useSmartAccount(eoaAddress?: string) {
  const { data, isLoading, error } = useReadContract({
    address: CONTRACTS.SMART_ACCOUNT_FACTORY.address as `0x${string}`,
    abi: CONTRACTS.SMART_ACCOUNT_FACTORY.abi,
    functionName: 'getAddress',
    args: eoaAddress
      ? [eoaAddress as `0x${string}`, BigInt(0)]
      : undefined,
    query: {
      enabled: !!eoaAddress,
    },
  });

  return {
    smartAccountAddress: data as string | undefined,
    isLoading: !!eoaAddress && isLoading,
    error,
  };
}
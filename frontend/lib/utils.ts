import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatAddress(address: string | undefined) {
  if (!address) return ""
  return `${address.slice(0, 6)}...${address.slice(-4)}`
}

export function formatBalance(balance: bigint | undefined, decimals: number = 18) {
  if (!balance) return "0"
  return (Number(balance) / 10 ** decimals).toFixed(4)
}
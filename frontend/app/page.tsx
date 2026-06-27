'use client';

import { usePrivy } from '@privy-io/react-auth';
import Login from '@/components/Login';
import Dashboard from '@/components/Dashboard';

export default function Page() {
  const { authenticated, ready } = usePrivy();

  if (!ready) return null; // tunggu privy init

  if (!authenticated) return <Login />;
  return <Dashboard />;
}
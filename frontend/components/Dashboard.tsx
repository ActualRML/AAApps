'use client';

import { usePrivy } from '@privy-io/react-auth';
import { useSmartAccount } from '@/hooks/useSmartAccount';
import { useState, useEffect } from 'react';
import { Geist_Mono } from 'next/font/google';
import { useRouter } from 'next/navigation';

const mono = Geist_Mono({ subsets: ['latin'] });

export default function Dashboard() {
  const { logout, user, ready, authenticated } = usePrivy();
  const router = useRouter();
  const [copied, setCopied] = useState(false);

  const eoaAddress = user?.wallet?.address;
  const { smartAccountAddress, isLoading, error } = useSmartAccount(eoaAddress);

  const copyToClipboard = (text?: string) => {
    if (!text) return;
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  useEffect(() => {
    if (ready && !authenticated) {
      router.push('/');
    }
  }, [ready, authenticated, router]);

  if (!ready || !authenticated) {
    return (
      <div className="fixed inset-0 bg-[#050505] flex items-center justify-center z-[999]">
        <div className={`${mono.className} text-teal-500 text-xs uppercase tracking-[0.3em] animate-pulse`}>
          Booting Terminal...
        </div>
      </div>
    );
  }

  return (
    // Gunakan fixed inset-0 atau w-screen h-screen untuk paksa full layar
    <div className={`fixed inset-0 bg-[#050505] text-white ${mono.className} flex flex-col overflow-hidden`}>
      
      {/* --- TOP NAVIGATION BAR --- */}
      <nav className="w-full border-b border-white/5 bg-black/40 backdrop-blur-md px-8 py-5 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-5">
          <div className="bg-indigo-600 px-3 py-1.5 rounded-lg text-[10px] font-black italic shadow-[0_0_20px_rgba(79,70,229,0.3)]">
            AA
          </div>
          <div className="flex flex-col">
            <span className="text-base font-black tracking-tighter uppercase leading-none">AAApps Terminal</span>
            <span className="text-[10px] text-indigo-500 font-bold mt-1">PROTOCOL: SEPOLIA_STABLE</span>
          </div>
        </div>

        <button 
          onClick={logout}
          className="text-[10px] font-bold uppercase tracking-[0.2em] text-zinc-500 hover:text-red-500 border border-white/5 hover:border-red-500/20 px-5 py-2.5 rounded-xl transition-all active:scale-95"
        >
          [ Terminate Session ]
        </button>
      </nav>

      {/* --- MAIN WORKSPACE (No Max Width) --- */}
      <main className="flex-grow flex flex-col lg:flex-row w-full overflow-hidden">
        
        {/* LEFT SECTOR: Main Terminal Data */}
        <section className="flex-grow lg:w-[65%] p-8 lg:p-16 border-r border-white/5 overflow-y-auto">
          <div className="w-full">
            <h2 className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.5em] mb-12 flex items-center gap-4">
              <span className="h-[1px] w-12 bg-zinc-800"></span>
              Account_Manifest
            </h2>

            <div className="space-y-16">
              {/* ADDRESS BLOCK */}
              <div>
                <p className="text-[11px] text-indigo-400 font-bold mb-5 uppercase tracking-[0.2em] flex items-center gap-3">
                  <span className="w-1.5 h-1.5 bg-indigo-500 rounded-full shadow-[0_0_8px_indigo]"></span>
                  Smart Account Hash
                </p>
                
                <div className="bg-white/[0.02] border border-white/10 rounded-[2rem] p-10 flex flex-col xl:flex-row xl:items-center justify-between gap-8 group hover:border-indigo-500/30 transition-all duration-500 shadow-2xl relative overflow-hidden">
                  <div className="absolute inset-0 bg-indigo-500/5 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none" />
                  
                  <div className="relative z-10 overflow-hidden">
                    {isLoading ? (
                      <div className="h-10 w-80 bg-white/5 animate-pulse rounded-xl"></div>
                    ) : (
                      <code className="text-2xl md:text-3xl lg:text-4xl font-bold tracking-tighter text-zinc-100 whitespace-nowrap overflow-hidden">
                        {smartAccountAddress ? 
                          `${smartAccountAddress.slice(0, 10)}...${smartAccountAddress.slice(-10)}` : 
                          '0x0000...0000'}
                      </code>
                    )}
                    <p className="text-[10px] text-zinc-600 mt-2 font-bold uppercase tracking-widest">Verified on Sepolia RPC</p>
                  </div>

                  <button 
                    onClick={() => copyToClipboard(smartAccountAddress)}
                    className="relative z-10 shrink-0 bg-white text-black px-10 py-5 rounded-2xl text-xs font-black uppercase tracking-widest hover:bg-indigo-400 transition-all active:scale-90 shadow-xl"
                  >
                    {copied ? 'Hash Copied' : 'Copy Hash'}
                  </button>
                </div>
              </div>

              {/* GRID STATS */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-12 pt-10">
                {[
                  { label: 'System Status', value: 'Active', color: 'text-teal-400' },
                  { label: 'Standard', value: 'ERC-4337', color: 'text-indigo-400' },
                  { label: 'Bundler', value: 'Syncing', color: 'text-zinc-500' },
                  { label: 'Version', value: 'v1.0.4', color: 'text-zinc-600' }
                ].map((item, i) => (
                  <div key={i} className="space-y-2 border-l border-zinc-900 pl-6">
                    <p className="text-[9px] text-zinc-600 uppercase font-black tracking-widest">{item.label}</p>
                    <p className={`text-sm font-black uppercase tracking-tighter ${item.color}`}>{item.value}</p>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </section>

        {/* RIGHT SECTOR: Controls & Signer */}
        <section className="lg:w-[35%] p-8 lg:p-16 bg-white/[0.01] flex flex-col justify-between border-t lg:border-t-0 border-white/5">
          <div className="space-y-12">
            <div>
              <h2 className="text-[10px] font-black text-zinc-600 uppercase tracking-[0.5em] mb-10 flex items-center gap-4">
                <span className="h-[1px] w-12 bg-zinc-800"></span>
                Security_Node
              </h2>
              
              <div className="bg-zinc-900/40 border border-white/5 p-8 rounded-[2rem] space-y-4">
                <p className="text-[10px] text-zinc-500 font-black uppercase tracking-widest">Primary Signer</p>
                <p className="text-base font-bold text-zinc-200 truncate border-b border-white/5 pb-4 leading-none">
                  {user?.email?.address || 'ANONYMOUS_EOA'}
                </p>
                <div className="flex items-center gap-2 text-[10px] text-teal-500 font-bold uppercase">
                  <span className="w-2 h-2 rounded-full bg-teal-500 shadow-[0_0_8px_teal]"></span>
                  Identity Confirmed
                </div>
              </div>
            </div>

            <div className="space-y-4">
              <button className="w-full py-7 bg-white text-black rounded-2xl font-black uppercase tracking-[0.3em] text-sm hover:scale-[1.02] active:scale-[0.98] transition-all shadow-[0_0_40px_rgba(255,255,255,0.1)]">
                Deploy Infra
              </button>
              <button className="w-full py-7 bg-transparent border border-white/10 text-zinc-500 rounded-2xl font-black uppercase tracking-[0.3em] text-sm hover:bg-white/5 transition-all">
                Transfer Assets
              </button>
            </div>
          </div>

          <div className="pt-10">
            <div className="text-[9px] text-zinc-700 font-bold uppercase tracking-[0.4em] leading-relaxed">
              Global Authorization Terminal <br />
              <span className="text-zinc-800 underline">Encrypted Connection // 256-bit</span>
            </div>
          </div>
        </section>
      </main>

      {/* --- FOOTER STATUS BAR --- */}
      <footer className="w-full border-t border-white/5 px-8 py-4 bg-black flex items-center justify-between shrink-0">
        <div className="flex gap-10 text-[9px] font-black uppercase tracking-[0.2em] text-zinc-600">
           <span className="text-teal-500/50">● INTERFACE_STABLE</span>
           <span>LOG_BUFFER: 0.00ms</span>
           <span>ID: {user?.id?.slice(0, 12)}...</span>
        </div>
        <div className="text-[9px] font-black uppercase tracking-[0.2em] text-zinc-700">
          ActualRML // Programmable Ownership
        </div>
      </footer>
    </div>
  );
}
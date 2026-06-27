'use client';

import { usePrivy } from '@privy-io/react-auth';
import { Geist_Mono } from 'next/font/google';
import { useEffect } from 'react';
import { useRouter } from 'next/navigation'; // Pastikan pakai router Next.js

const mono = Geist_Mono({ subsets: ['latin'] });

export default function Login() {
  // Ambil authenticated dan ready dari usePrivy
  const { login, authenticated, ready } = usePrivy();
  const router = useRouter();

  // Logic: Kalau sudah login (authenticated), langsung tendang ke dashboard
  useEffect(() => {
    if (ready && authenticated) {
      router.push('/dashboard'); // Ganti path sesuai route dashboard kamu
    }
  }, [ready, authenticated, router]);

  // Sambil nunggu Privy nge-cek session (ready = false), 
  // kita kasih state kosong atau loading biar gak flicker login screen
  if (!ready || authenticated) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-black">
        <div className="animate-pulse font-mono text-teal-500 text-xs uppercase tracking-[0.3em]">
          Verifying Session...
        </div>
      </div>
    );
  }

  return (
    <>
      {/* CARD */}
      <div className="relative w-full bg-white/[0.04] backdrop-blur-3xl 
      border border-white/10 
      shadow-[0_20px_80px_-20px_rgba(0,0,0,0.8),_0_0_40px_rgba(45,212,191,0.08)] 
      p-10 rounded-[2.5rem] flex flex-col items-center">

        {/* INNER GLOW */}
        <div className="absolute inset-0 rounded-[2.5rem] pointer-events-none 
        bg-[radial-gradient(circle_at_50%_0%,rgba(255,255,255,0.08),transparent_60%)]" />

        {/* HEADER */}
        <div className="text-center mb-10 w-full flex flex-col items-center">
          <div className="relative inline-flex mb-6">
            <div className="absolute inset-0 bg-indigo-500 blur-xl opacity-40 animate-pulse"></div>
            <div className="relative inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-gradient-to-br from-indigo-500 to-indigo-700 shadow-inner">
              <span className="text-2xl font-black text-white italic tracking-tighter">
                AA
              </span>
            </div>
          </div>

          <h1 className="text-3xl font-black tracking-tighter text-white mb-2 uppercase">
            AAApps <span className="text-teal-400 font-mono">Terminal</span>
          </h1>

          <p className="text-gray-400 text-sm font-medium leading-tight">
            Programmable Ownership Terminal <br />
            <span className="text-gray-600 text-[11px] font-mono tracking-wider italic">
              v1.0.4 // protocol_stable
            </span>
          </p>
        </div>

        {/* ACTION */}
        <div className="space-y-6 w-full">
          <button
            onClick={login}
            className="group relative w-full flex items-center justify-center gap-3 
            bg-white text-black font-extrabold py-4 px-6 rounded-2xl 
            hover:scale-[1.03] 
            hover:shadow-[0_0_30px_rgba(45,212,191,0.8)] 
            active:scale-[0.97] 
            transition-all duration-300"
          >
            <span>Initialize Session</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth={2.5}
              stroke="currentColor"
              className="w-5 h-5 group-hover:translate-x-1 transition-transform"
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M13.5 4.5L21 12m0 0l-7.5 7.5M21 12H3" />
            </svg>
          </button>

          <div className="flex items-center gap-3">
            <span className="h-[1px] w-full bg-gradient-to-r from-transparent via-white/10 to-transparent"></span>
            <p className="text-[10px] font-bold text-gray-500 uppercase tracking-[0.2em] whitespace-nowrap">
              Auth via Privy
            </p>
            <span className="h-[1px] w-full bg-gradient-to-l from-transparent via-white/10 to-transparent"></span>
          </div>
        </div>

        {/* STATUS */}
        <div className="mt-12 w-full pt-6 border-t border-white/5 grid grid-cols-2 gap-4">
          <div className="flex flex-col gap-1">
            <span className={`text-[9px] text-gray-600 uppercase font-bold tracking-widest ${mono.className}`}>
              Network
            </span>
            <p className="text-xs font-mono text-indigo-300 flex items-center gap-1.5">
              <span className="w-1.5 h-1.5 rounded-full bg-indigo-500 shadow-[0_0_8px_rgba(139,92,246,0.6)]"></span>
              Sepolia
            </p>
          </div>

          <div className="flex flex-col gap-1 text-right">
            <span className={`text-[9px] text-gray-600 uppercase font-bold tracking-widest ${mono.className}`}>
              Status
            </span>
            <p className="text-xs font-mono text-teal-400">
              Stable & Active
            </p>
          </div>
        </div>
      </div>
    </>
  );
}
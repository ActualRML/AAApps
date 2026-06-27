'use client';

import './globals.css'; 
import { Web3Provider } from '@/providers/Web3Provider';
import { Inter, JetBrains_Mono } from 'next/font/google';

const inter = Inter({ subsets: ['latin'] });
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' });

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" className="dark" style={{ colorScheme: 'dark' }}>
      {/* 1. BASE COLOR: Biru-Hitam super-dalam untuk memaksimalkan glow */}
      <body className={`${inter.className} ${mono.variable} bg-[#020409] text-white antialiased`}>
        <Web3Provider>
          {/* Main Layout Wrapper */}
          <div className="relative min-h-screen w-full overflow-hidden flex flex-col items-center justify-center p-6">
            
            {/* --- THEME WRAPPER START (Vibe Alymus) --- */}
            
            {/* 2. AGGRESSIVE GLOBAL GLOW: Pendaran Cyan/Purple yang pekat di tengah layar.
                   Ini meniru atmosfera di image 6.png. */}
            <div className="pointer-events-none absolute inset-0 z-0 opacity-80 mix-blend-screen">
              <div 
                className="absolute left-1/2 top-1/2 h-[70vh] w-[150vw] -translate-x-1/2 -translate-y-[45%] rounded-full z-0"
                style={{
                  background: `
                    radial-gradient(circle at center, 
                      rgba(45, 212, 191, 0.35) 0%,
                      rgba(59, 130, 246, 0.2) 25%,
                      rgba(139, 92, 246, 0.15) 55%,
                      transparent 75%
                    )
                  `,
                  filter: 'blur(120px)',
                }}
              />
            </div>

            {/* 3. SUBTLE MESH/GRID PATTERN: Grid tipis yang pudar di pinggir */}
            <div 
              className="pointer-events-none fixed inset-0 z-0 opacity-[0.12]" 
              style={{ 
                backgroundImage: `
                  linear-gradient(rgba(255,255,255,0.05) 1px, transparent 1px), 
                  linear-gradient(90deg, rgba(255,255,255,0.05) 1px, transparent 1px)
                `, 
                backgroundSize: '40px 40px',
                maskImage: 'radial-gradient(circle at center, black, transparent 80%)'
              }}
            />
            {/* --- THEME WRAPPER END --- */}

            {/* 4. CONTENT (Card Login) */}
            <div className="relative z-10 w-full max-w-sm flex flex-col items-center">
              {children}
            </div>

          </div>
        </Web3Provider>
      </body>
    </html>
  );
}
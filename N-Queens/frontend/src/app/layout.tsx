import type { Metadata } from 'next';
import { Inter, JetBrains_Mono } from 'next/font/google';
import './globals.css';

const inter = Inter({ subsets: ['latin'], variable: '--font-sans' });
const mono = JetBrains_Mono({ subsets: ['latin'], variable: '--font-mono' });

export const metadata: Metadata = {
  title: 'N-Queens Tactical Visualizer',
  description: 'Real-time 3D N-Queens backtracking simulation with React Three Fiber and FastAPI SSE',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark" suppressHydrationWarning>
      <body className={`${inter.variable} ${mono.variable} font-sans bg-black text-white overflow-hidden`} suppressHydrationWarning>
        {children}
      </body>
    </html>
  );
}

import Image from 'next/image';

export default function ParallaxBackground() {
  return (
    <div className="absolute inset-0 z-0 overflow-hidden pointer-events-none">
      {/* Dark gradient overlay */}
      <div className="absolute inset-0 bg-gradient-to-b from-black/60 via-black/40 to-black/80 z-10" />
      <div className="absolute inset-0 bg-gradient-to-r from-slate-950/80 via-transparent to-slate-950/80 z-10" />

      {/* Background texture/image placeholder */}
      <div
        className="absolute inset-[-20%] w-[140%] h-[140%] opacity-30"
        style={{
          backgroundImage: 'radial-gradient(circle at 30% 30%, #1e3a5f 0%, transparent 60%), radial-gradient(circle at 70% 70%, #0f2e4a 0%, transparent 50%)',
        }}
      />

      {/* Subtle grid pattern */}
      <div
        className="absolute inset-0 opacity-[0.08]"
        style={{
          backgroundImage: 'linear-gradient(rgba(6, 182, 212, 0.3) 1px, transparent 1px), linear-gradient(90deg, rgba(6, 182, 212, 0.3) 1px, transparent 1px)',
          backgroundSize: '60px 60px',
        }}
      />
    </div>
  );
}

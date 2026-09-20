import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  reactStrictMode: false,
  transpilePackages: ['three'],
  output: 'standalone',
  images: {
    unoptimized: true,
  },
};

export default nextConfig;

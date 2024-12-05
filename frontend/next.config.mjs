/** @type {import('next').NextConfig} */
import './env-loader.js';

const nextConfig = {
  reactStrictMode: true,
  env: {
    // Transfere variáveis do processo para o ambiente Next.js
    NEXT_PUBLIC_API_BASE_URL: process.env.NEXT_PUBLIC_API_BASE_URL,
  },
};

export default nextConfig;

/** @type {import('next').NextConfig} */
const nextConfig = {
  transpilePackages: ["@paw-time/api-contracts", "@paw-time/game-catalog", "@paw-time/shop-console"],
  async redirects() {
    // The house and evaluations pages became the shop island and the reviews page.
    return [
      { source: "/house", destination: "/reviews", permanent: false },
      { source: "/evaluations", destination: "/reviews", permanent: false },
    ];
  },
};

export default nextConfig;

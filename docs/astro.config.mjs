// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

const target = process.env.DEPLOY_TARGET;
const isGitHubPages = target === 'github';

const vercelUrl = process.env.VERCEL_URL;
const vercelProjectProductionUrl = process.env.VERCEL_PROJECT_PRODUCTION_URL;

const site = isGitHubPages
  ? 'https://it-bill.github.io'
  : vercelUrl
    ? `https://${vercelUrl}`
    : vercelProjectProductionUrl
      ? `https://${vercelProjectProductionUrl}`
      : 'https://bicone.it-bill.com';

// https://astro.build/config
export default defineConfig({
  site,
  base: isGitHubPages ? '/BiCone/' : '/',
  trailingSlash: 'always',
  vite: {
    plugins: [/** @type {any} */ (tailwindcss())]
  }
});

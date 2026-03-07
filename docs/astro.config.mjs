// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

const target = process.env.DEPLOY_TARGET

const isGitHubPages = target === 'github'

// https://astro.build/config
export default defineConfig({
  site: isGitHubPages
    ? 'https://it-bill.github.io'
    : 'https://bicone.it-bill.com',
  base: isGitHubPages ? '/BiCone/' : '/',
  trailingSlash: 'always',
  vite: {
    plugins: [tailwindcss()]
  }
});

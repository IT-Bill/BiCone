// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://IT-Bill.github.io',
  base: '/BiCone/',
  trailingSlash: 'always',
  vite: {
    plugins: [tailwindcss()]
  }
});
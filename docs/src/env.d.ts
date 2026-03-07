/// <reference types="astro/client" />

interface ImportMeta {
  readonly env: ImportMetaEnv;
}

interface ImportMetaEnv {
  readonly BASE_URL: string;
  readonly MODE: string;
  readonly DEV: boolean;
  readonly PROD: boolean;
  readonly SSR: boolean;
  readonly SITE: string | undefined;
  readonly ASSETS_PREFIX: string | undefined;
}

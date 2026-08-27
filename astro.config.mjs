import { defineConfig } from 'astro/config';
import preact from "@astrojs/preact";

// https://astro.build/config
// Tailwind runs via PostCSS (see postcss.config.mjs); the deprecated
// @astrojs/tailwind wrapper is no longer needed.
export default defineConfig({
  integrations: [preact()]
});
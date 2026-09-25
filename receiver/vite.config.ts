import { defineConfig } from 'vite';
import { fileURLToPath } from 'node:url';

// Le receiver réutilise le moteur de /renderer tel quel (un seul bundle logique).
export default defineConfig({
  base: './',
  resolve: {
    alias: {
      '@renderer': fileURLToPath(new URL('../renderer/src', import.meta.url)),
    },
  },
  server: {
    fs: { allow: ['..'] },
  },
  build: {
    target: 'es2020',
    outDir: 'dist',
  },
});

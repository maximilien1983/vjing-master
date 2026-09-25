import { defineConfig } from 'vite';

// base relative : le même bundle se sert depuis GitHub Pages (sous-chemin),
// depuis les assets Flutter en WebView, et depuis l'enveloppe receiver.
export default defineConfig({
  base: './',
  build: {
    target: 'es2020',
    outDir: 'dist',
  },
});

import { defineConfig } from 'vite';
import { viteSingleFile } from 'vite-plugin-singlefile';

// Build embarqué : tout est inliné dans un seul index.html, copié dans les
// assets Flutter (les modules ES externes ne se chargent pas depuis file://
// dans une WebView). Le build hébergé (vite.config.ts) reste celui de Pages.
export default defineConfig({
  base: './',
  plugins: [viteSingleFile()],
  build: {
    target: 'es2020',
    outDir: 'dist-embed',
  },
});

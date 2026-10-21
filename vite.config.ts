import { defineConfig } from 'vite';
// base './' keeps asset paths relative so the build works from a GitHub Pages sub-path (user.github.io/repo/).
export default defineConfig({ base: './', server: { host: true, port: 5173 }, build: { target: 'es2022', chunkSizeWarningLimit: 4000 } });

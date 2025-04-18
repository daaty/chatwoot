import { defineConfig } from 'vite';
import { fileURLToPath, URL } from 'node:url';
import vue from '@vitejs/plugin-vue2';
import ViteRuby from 'vite-plugin-ruby';

// Importação básica da configuração existente
import baseConfig from './vite.config';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    ViteRuby(),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./app/javascript', import.meta.url)),
      '~public': fileURLToPath(new URL('./public', import.meta.url)),
      'dashboard': fileURLToPath(new URL('./app/javascript/dashboard', import.meta.url)),
      'widget': fileURLToPath(new URL('./app/javascript/widget', import.meta.url)),
      'shared': fileURLToPath(new URL('./app/javascript/shared', import.meta.url)),
    }
  },
  build: {
    // Otimizações para lidar com projetos grandes
    chunkSizeWarningLimit: 2000,
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
      },
    },
    rollupOptions: {
      output: {
        // Estratégia de divisão de código mais eficiente
        manualChunks(id) {
          if (id.includes('node_modules')) {
            // Agrupa bibliotecas comuns para carregar menos chunks
            if (id.includes('vue')) return 'vue-vendor';
            if (id.includes('axios')) return 'axios-vendor';
            if (id.includes('lodash')) return 'lodash-vendor';
            return 'vendor'; // Demais pacotes de terceiros
          }
        },
      },
    },
  },
  // Reduzir o tamanho dos logs de build
  logLevel: 'error',
});

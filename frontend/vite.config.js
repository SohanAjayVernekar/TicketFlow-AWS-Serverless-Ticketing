import vue from '@vitejs/plugin-vue'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [vue()],

  server: {
    host: '0.0.0.0',

    allowedHosts: [
      'frenzied-surpass-clumsily.ngrok-free.dev',
    ],

    hmr: {
      protocol: 'wss',
      host: 'frenzied-surpass-clumsily.ngrok-free.dev',
      clientPort: 443,
    },
  },
})

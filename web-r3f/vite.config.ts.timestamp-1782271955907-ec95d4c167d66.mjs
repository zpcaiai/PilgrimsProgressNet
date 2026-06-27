// vite.config.ts
import { defineConfig } from "file:///sessions/great-awesome-darwin/mnt/PilgrimsProgressNet/web-r3f/node_modules/vite/dist/node/index.js";
import react from "file:///sessions/great-awesome-darwin/mnt/PilgrimsProgressNet/web-r3f/node_modules/@vitejs/plugin-react/dist/index.js";
var vite_config_default = defineConfig({
  plugins: [react()],
  server: { host: true },
  build: {
    chunkSizeWarningLimit: 1200,
    rollupOptions: {
      output: {
        // Split the heavy 3D stack and React out of the app chunk; each lazy
        // chapter scene becomes its own chunk (see SceneRouter).
        manualChunks(id) {
          if (id.includes("node_modules")) {
            if (id.includes("three") || id.includes("@react-three")) return "three-vendor";
            if (id.includes("react") || id.includes("scheduler")) return "react-vendor";
            return "vendor";
          }
        }
      }
    }
  }
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCIvc2Vzc2lvbnMvZ3JlYXQtYXdlc29tZS1kYXJ3aW4vbW50L1BpbGdyaW1zUHJvZ3Jlc3NOZXQvd2ViLXIzZlwiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiL3Nlc3Npb25zL2dyZWF0LWF3ZXNvbWUtZGFyd2luL21udC9QaWxncmltc1Byb2dyZXNzTmV0L3dlYi1yM2Yvdml0ZS5jb25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL3Nlc3Npb25zL2dyZWF0LWF3ZXNvbWUtZGFyd2luL21udC9QaWxncmltc1Byb2dyZXNzTmV0L3dlYi1yM2Yvdml0ZS5jb25maWcudHNcIjtpbXBvcnQgeyBkZWZpbmVDb25maWcgfSBmcm9tICd2aXRlJ1xuaW1wb3J0IHJlYWN0IGZyb20gJ0B2aXRlanMvcGx1Z2luLXJlYWN0J1xuXG5leHBvcnQgZGVmYXVsdCBkZWZpbmVDb25maWcoe1xuICBwbHVnaW5zOiBbcmVhY3QoKV0sXG4gIHNlcnZlcjogeyBob3N0OiB0cnVlIH0sXG4gIGJ1aWxkOiB7XG4gICAgY2h1bmtTaXplV2FybmluZ0xpbWl0OiAxMjAwLFxuICAgIHJvbGx1cE9wdGlvbnM6IHtcbiAgICAgIG91dHB1dDoge1xuICAgICAgICAvLyBTcGxpdCB0aGUgaGVhdnkgM0Qgc3RhY2sgYW5kIFJlYWN0IG91dCBvZiB0aGUgYXBwIGNodW5rOyBlYWNoIGxhenlcbiAgICAgICAgLy8gY2hhcHRlciBzY2VuZSBiZWNvbWVzIGl0cyBvd24gY2h1bmsgKHNlZSBTY2VuZVJvdXRlcikuXG4gICAgICAgIG1hbnVhbENodW5rcyhpZCkge1xuICAgICAgICAgIGlmIChpZC5pbmNsdWRlcygnbm9kZV9tb2R1bGVzJykpIHtcbiAgICAgICAgICAgIGlmIChpZC5pbmNsdWRlcygndGhyZWUnKSB8fCBpZC5pbmNsdWRlcygnQHJlYWN0LXRocmVlJykpIHJldHVybiAndGhyZWUtdmVuZG9yJ1xuICAgICAgICAgICAgaWYgKGlkLmluY2x1ZGVzKCdyZWFjdCcpIHx8IGlkLmluY2x1ZGVzKCdzY2hlZHVsZXInKSkgcmV0dXJuICdyZWFjdC12ZW5kb3InXG4gICAgICAgICAgICByZXR1cm4gJ3ZlbmRvcidcbiAgICAgICAgICB9XG4gICAgICAgIH0sXG4gICAgICB9LFxuICAgIH0sXG4gIH0sXG59KVxuIl0sCiAgIm1hcHBpbmdzIjogIjtBQUE0VyxTQUFTLG9CQUFvQjtBQUN6WSxPQUFPLFdBQVc7QUFFbEIsSUFBTyxzQkFBUSxhQUFhO0FBQUEsRUFDMUIsU0FBUyxDQUFDLE1BQU0sQ0FBQztBQUFBLEVBQ2pCLFFBQVEsRUFBRSxNQUFNLEtBQUs7QUFBQSxFQUNyQixPQUFPO0FBQUEsSUFDTCx1QkFBdUI7QUFBQSxJQUN2QixlQUFlO0FBQUEsTUFDYixRQUFRO0FBQUE7QUFBQTtBQUFBLFFBR04sYUFBYSxJQUFJO0FBQ2YsY0FBSSxHQUFHLFNBQVMsY0FBYyxHQUFHO0FBQy9CLGdCQUFJLEdBQUcsU0FBUyxPQUFPLEtBQUssR0FBRyxTQUFTLGNBQWMsRUFBRyxRQUFPO0FBQ2hFLGdCQUFJLEdBQUcsU0FBUyxPQUFPLEtBQUssR0FBRyxTQUFTLFdBQVcsRUFBRyxRQUFPO0FBQzdELG1CQUFPO0FBQUEsVUFDVDtBQUFBLFFBQ0Y7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLEVBQ0Y7QUFDRixDQUFDOyIsCiAgIm5hbWVzIjogW10KfQo=

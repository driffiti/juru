/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        void: {
          DEFAULT: "#07050c",
          soft: "#0d0a16",
          card: "#120e1d",
        },
        violet: {
          glow: "#a374ff",
          core: "#7c3aed",
          deep: "#4c1d95",
          dim: "#2a1a4a",
        },
        mist: "#c9c3dd",
      },
      fontFamily: {
        display: ["var(--font-display)", "sans-serif"],
        body: ["var(--font-body)", "sans-serif"],
        mono: ["var(--font-mono)", "monospace"],
      },
      boxShadow: {
        glow: "0 0 40px -10px rgba(124, 58, 237, 0.45)",
        glowSm: "0 0 18px -6px rgba(163, 116, 255, 0.55)",
      },
      backgroundImage: {
        grid: "linear-gradient(rgba(124,58,237,0.09) 1px, transparent 1px), linear-gradient(90deg, rgba(124,58,237,0.09) 1px, transparent 1px)",
      },
      backgroundSize: {
        grid: "42px 42px",
      },
    },
  },
  plugins: [],
};

/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
	theme: {
		fontFamily: {
			'roboto': ['Roboto', 'sans-serif'],
		},
		extend: {
			keyframes: {
				fadeIn: {
					'0%': { opacity: 0 },
					'100%': { opacity: 1 }
				}
			},
			animation: {
				fadeIn: 'fadeIn .5s ease-in',
			}
		},
	},
	plugins: [],
}

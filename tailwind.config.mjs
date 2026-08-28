/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
	theme: {
		extend: {
			fontFamily: {
				sans: ['Bricolage Grotesque Variable', 'Helvetica Neue', 'Arial', 'sans-serif'],
			},
			colors: {
				paper: '#f2f1ec',
				ink: '#101013',
				accent: '#2b3cf2',
				'accent-dark': '#6472ff',
				muted: '#6a6a70',
				'muted-dark': '#8b8b93',
				body: '#33333a',
				'body-dark': '#c9c9cf',
				hairline: '#c9c8c0',
				'hairline-dark': '#2e2e33',
			},
		},
	},
	plugins: [],
}

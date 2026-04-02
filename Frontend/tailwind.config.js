/** @type {import('tailwindcss').Config} */
module.exports = {
	content: [
		'./**/*.html',
		'./**/*.css',
	],
	theme: {
		extend: {
			colors: {
				background: '#1e1f23',
				darker: '#313865',
				dark: '#504099',
				accent: '#974EC2',
				light: '#fe7bbf',
				lighter: '#fefefe'
			}
		},
	},
	plugins: [],
}

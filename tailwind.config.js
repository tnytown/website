module.exports = {
    mode: 'jit',
    content: [
        './content/**/*.md',
        './templates/**/*.html',
    ],
    theme: {
        extend: {
            fontFamily: {
                meow: ['Recursive', 'sans-serif'],
            },
            keyframes: {
                'meow': {
                    '0%': { transform: 'translate(-50%) scale(0.5)' },
                    '100%': { transform: 'translate(-25%) scale(0.75)' },
                },
            },
            animation: { 'meow': 'meow 0.125s linear' },
            minHeight: { 'stretch': 'stretch' },
            typography: (theme) => ({
                'dark': {
                    css: {
                        color: theme("colors.gray.50"),
                        code: {
                            color: theme("colors.red.500"),
                        },
                        h1: {
                            color: theme('colors.gray.300'),
                        },
                        h2: {
                            color: theme('colors.gray.300'),
                        },
                        h3: {
                            color: theme('colors.gray.300'),
                        },
                        h4: {
                            color: theme('colors.gray.300'),
                        },
                        h5: {
                            color: theme('colors.gray.300'),
                        },
                        h6: {
                            color: theme('colors.gray.300'),
                        },
                        blockquote: {
                            color: theme('colors.gray.300'),
                            'border-left-color': theme('colors.gray.700'),
                        },

                        /* footnote block display
                           TODO: this should not be theme-dependent */
                        'sup + p': {
                            display: 'inline'
                        }
                    }
                }
            }),
        }
    },
    plugins: [
        require('@tailwindcss/typography'),
    ],
}

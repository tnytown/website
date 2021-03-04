module.exports = {
    purge: [
        './content/**/*.md',
        './templates/**/*.html',
    ],
    darkMode: false, // TODO: dark mode toggle
    theme: {
        extend: {
            minHeight: {
                'stretch': 'stretch'
            },
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
    variants: {
        extend: {},
    },
    plugins: [
        require('@tailwindcss/typography'),
    ],
}

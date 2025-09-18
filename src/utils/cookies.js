export const cookies = {
    getOptions: () => ({
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict',
        maxAge: 1 * 24 * 60 * 60 * 1000,
    }),

    set: (res, name, value, options = {}) => {
        res.cookie(name, value, { ...cookies.getOptions(), ...options });
    },

    clear: (res, name, options = {}) => {
        res.clearCookie(name, { ...cookies.getOptions(), ...options });
    },

    get: (req, name) => {
        return req.cookies[name];
    },
};

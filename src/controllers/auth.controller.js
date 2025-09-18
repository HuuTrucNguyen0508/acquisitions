import logger from '#config/logger.js';
import { formatValidationErrors } from '#utils/format.js';
import { signUpSchema, signInSchema } from '#validations/auth.validation.js';
import { createUser, authenticateUser } from '#services/auth.services.js';
import { jwttoken } from '#utils/jwt.js';
import { cookies } from '#utils/cookies.js';

export const signup = async (req, res, next) => {
    try {
        const validationResult = signUpSchema.safeParse(req.body);

        if (!validationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(validationResult.error),
            });
        }

        const { name, email, password, role } = validationResult.data;

        const user = await createUser({ name, email, password, role });

        const token = jwttoken.sign({
            id: user.id,
            email: user.email,
            role: user.role,
        });

        cookies.set(res, 'token', token);

        logger.info(`User registered successfully: ${email}`);
        res.status(201).json({
            message: 'User registered',
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
        });
    } catch (e) {
        logger.error('Signup error', e);

        if (e.message === 'User with email already exists') {
            return res.status(409).json({ error: 'Email already exists' });
        }

        next(e);
    }
};

export const signin = async (req, res, next) => {
    try {
        const validationResult = signInSchema.safeParse(req.body);

        if (!validationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(validationResult.error),
            });
        }

        const { email, password } = validationResult.data;

        const user = await authenticateUser({ email, password });

        const token = jwttoken.sign({
            id: user.id,
            email: user.email,
            role: user.role,
        });

        cookies.set(res, 'token', token);

        logger.info(`User signed in successfully: ${email}`);
        res.status(200).json({
            message: 'Sign in successful',
            user: {
                id: user.id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
        });
    } catch (e) {
        logger.error('Signin error', e);

        if (e.message === 'Invalid email or password') {
            return res.status(401).json({ error: 'Invalid email or password' });
        }

        next(e);
    }
};

export const signout = async (req, res, next) => {
    try {
        cookies.clear(res, 'token');

        logger.info('User signed out successfully');
        res.status(200).json({
            message: 'Sign out successful',
        });
    } catch (e) {
        logger.error('Signout error', e);
        next(e);
    }
};

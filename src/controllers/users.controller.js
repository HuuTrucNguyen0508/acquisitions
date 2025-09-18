import logger from '#config/logger.js';
import {
    getAllUsers,
    getUserById as getUserByIdService,
    updateUser as updateUserService,
    deleteUser as deleteUserService,
} from '#services/users.services.js';
import { formatValidationErrors } from '#utils/format.js';
import {
    userIdSchema,
    updateUserSchema,
} from '#validations/users.validation.js';

export const fetchAllUsers = async (req, res, next) => {
    try {
        logger.info('Getting all users');

        const allUsers = await getAllUsers();

        res.json({
            message: 'Successfully fetched all users',
            users: allUsers,
            count: allUsers.length,
        });
    } catch (e) {
        logger.error('Error getting all users', e);
        res.status(500).json({ message: 'Error getting all users' });
        next(e);
    }
};

export const getUserById = async (req, res, next) => {
    try {
        // Validate the ID parameter
        const validationResult = userIdSchema.safeParse({ id: req.params.id });

        if (!validationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(validationResult.error),
            });
        }

        const { id } = validationResult.data;

        logger.info(`Getting user by ID: ${id}`);

        const user = await getUserByIdService(id);

        res.json({
            message: 'Successfully fetched user',
            user,
        });
    } catch (e) {
        logger.error(`Error getting user by ID: ${req.params.id}`, e);

        if (e.message === 'User not found') {
            return res.status(404).json({ error: 'User not found' });
        }

        res.status(500).json({ message: 'Error getting user' });
        next(e);
    }
};

export const updateUser = async (req, res, next) => {
    try {
        // Validate the ID parameter
        const idValidationResult = userIdSchema.safeParse({
            id: req.params.id,
        });

        if (!idValidationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(idValidationResult.error),
            });
        }

        // Validate the update data
        const updateValidationResult = updateUserSchema.safeParse(req.body);

        if (!updateValidationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(updateValidationResult.error),
            });
        }

        const { id } = idValidationResult.data;
        const updates = updateValidationResult.data;

        // Check if user is authenticated
        if (!req.user) {
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required',
            });
        }

        // Check authorization: users can only update their own info, admins can update anyone
        if (req.user.role !== 'admin' && req.user.id !== id) {
            return res.status(403).json({
                error: 'Forbidden',
                message: 'You can only update your own information',
            });
        }

        // Only admins can change roles
        if (updates.role && req.user.role !== 'admin') {
            return res.status(403).json({
                error: 'Forbidden',
                message: 'Only administrators can change user roles',
            });
        }

        logger.info(`Updating user ID: ${id}`, {
            updatedBy: req.user.id,
            updates: Object.keys(updates),
        });

        const updatedUser = await updateUserService(id, updates);

        res.json({
            message: 'User updated successfully',
            user: updatedUser,
        });
    } catch (e) {
        logger.error(`Error updating user ID: ${req.params.id}`, e);

        if (e.message === 'User not found') {
            return res.status(404).json({ error: 'User not found' });
        }

        if (e.message === 'Email already exists') {
            return res.status(409).json({ error: 'Email already exists' });
        }

        res.status(500).json({ message: 'Error updating user' });
        next(e);
    }
};

export const deleteUser = async (req, res, next) => {
    try {
        // Validate the ID parameter
        const validationResult = userIdSchema.safeParse({ id: req.params.id });

        if (!validationResult.success) {
            return res.status(400).json({
                error: 'Validation failed',
                details: formatValidationErrors(validationResult.error),
            });
        }

        const { id } = validationResult.data;

        // Check if user is authenticated
        if (!req.user) {
            return res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required',
            });
        }

        // Check authorization: users can delete their own account, admins can delete any account
        if (req.user.role !== 'admin' && req.user.id !== id) {
            return res.status(403).json({
                error: 'Forbidden',
                message: 'You can only delete your own account',
            });
        }

        // Prevent users from deleting themselves if they're the only admin (optional safety check)
        if (req.user.id === id && req.user.role === 'admin') {
            // You might want to add logic here to check if there are other admins
            logger.warn(
                `Admin user ${id} attempting to delete their own account`
            );
        }

        logger.info(`Deleting user ID: ${id}`, { deletedBy: req.user.id });

        const deletedUser = await deleteUserService(id);

        res.json({
            message: 'User deleted successfully',
            deletedUser: {
                id: deletedUser.id,
                name: deletedUser.name,
                email: deletedUser.email,
                role: deletedUser.role,
            },
        });
    } catch (e) {
        logger.error(`Error deleting user ID: ${req.params.id}`, e);

        if (e.message === 'User not found') {
            return res.status(404).json({ error: 'User not found' });
        }

        res.status(500).json({ message: 'Error deleting user' });
        next(e);
    }
};

import express from 'express';
import {
    fetchAllUsers,
    getUserById,
    updateUser,
    deleteUser,
} from '#controllers/users.controller.js';
import { authenticateToken } from '#middleware/auth.middleware.js';

const router = express.Router();

// Public route - get all users (you might want to protect this too)
router.get('/', fetchAllUsers);

// Protected routes - require authentication
router.get('/:id', authenticateToken, getUserById);
router.put('/:id', authenticateToken, updateUser);
router.delete('/:id', authenticateToken, deleteUser);

export default router;

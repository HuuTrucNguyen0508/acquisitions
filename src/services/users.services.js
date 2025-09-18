import { db } from '#config/database.js';
import { users } from '#models/user.model.js';
import { eq } from 'drizzle-orm';
import logger from '#config/logger.js';

export const getAllUsers = async () => {
    try {
        return await db.select({
            id: users.id,
            name: users.name,
            email: users.email,
            role: users.role,
            createdAt: users.createdAt,
            updatedAt: users.updatedAt,
        }).from(users);
    } catch (e) {
        logger.error('Error getting all users', e);
        throw e;
    }
};

export const getUserById = async (id) => {
    try {
        const result = await db.select({
            id: users.id,
            name: users.name,
            email: users.email,
            role: users.role,
            createdAt: users.createdAt,
            updatedAt: users.updatedAt,
        }).from(users).where(eq(users.id, id));

        if (result.length === 0) {
            throw new Error('User not found');
        }

        return result[0];
    } catch (e) {
        logger.error(`Error getting user by ID ${id}`, e);
        throw e;
    }
};

export const updateUser = async (id, updates) => {
    try {
        // First check if user exists
        const existingUser = await getUserById(id);
        
        // Check if email is being updated and if it already exists
        if (updates.email && updates.email !== existingUser.email) {
            const emailExists = await db.select({ id: users.id })
                .from(users)
                .where(eq(users.email, updates.email));
            
            if (emailExists.length > 0) {
                throw new Error('Email already exists');
            }
        }

        // Add updatedAt timestamp
        const updateData = {
            ...updates,
            updatedAt: new Date()
        };

        const result = await db.update(users)
            .set(updateData)
            .where(eq(users.id, id))
            .returning({
                id: users.id,
                name: users.name,
                email: users.email,
                role: users.role,
                createdAt: users.createdAt,
                updatedAt: users.updatedAt,
            });

        return result[0];
    } catch (e) {
        logger.error(`Error updating user ${id}`, e);
        throw e;
    }
};

export const deleteUser = async (id) => {
    try {
        // First check if user exists
        await getUserById(id);

        const result = await db.delete(users)
            .where(eq(users.id, id))
            .returning({
                id: users.id,
                name: users.name,
                email: users.email,
                role: users.role
            });

        return result[0];
    } catch (e) {
        logger.error(`Error deleting user ${id}`, e);
        throw e;
    }
};

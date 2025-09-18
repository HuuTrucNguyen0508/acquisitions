import bcrypt from 'bcrypt';
import logger from '#config/logger.js';
import { users } from '#models/user.model.js';
import { eq } from 'drizzle-orm';
import { db } from '#config/database.js';

export const hashPassword = async (password) => {
    try{
        return await bcrypt.hash(password, 10);
    } catch (e){
        logger.error(`Error hashing password', ${e}`);
        throw new Error('Error hashing');
    }
};

export const createUser = async ({name, email, password, role = 'user'}) => {
    try{
        const existingUser = await db.select().from(users).where(eq(users.email, email)).limit(1);

        if(existingUser.length > 0) throw new Error('User with email already exists');

        const password_hash = await hashPassword(password);
        
        const [newUser] = await db
            .insert(users)
            .values({ name, email, password: password_hash, role })
            .returning({ id: users.id, name: users.name, email: users.email, role: users.role, createdAt: users.createdAt });
        
        logger.info(`User ${newUser.email} created successfully`);
        return newUser;     
    } catch (e){
        logger.error(`Error creating the user: ${e}`);
        throw e;
    }
};


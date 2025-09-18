import logger from '#config/logger.js';
import { getAllUsers} from '#services/users.services.js';

export const fetchAllUsers = async (req, res, next) => {
    try{
        logger.info('Getting all users');

        const allUsers = await getAllUsers();
        
        res.json({
            message: 'Successfully fetched all users',
            users: allUsers,
            count: allUsers.length,
        });
        
    } catch(e) {
        logger.error('Error getting all users', e);
        res.status(500).json({ message: 'Error getting all users' });
        next(e);
    }
};
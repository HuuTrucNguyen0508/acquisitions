# User CRUD API Documentation

This document describes the newly implemented User CRUD operations.

## Authentication

All protected endpoints require authentication via JWT token stored in cookies. The token is set during login and contains user information including ID, email, and role.

## Endpoints

### 1. Get User by ID
- **URL**: `GET /api/users/:id`
- **Authentication**: Required
- **Authorization**: Users can access their own data, admins can access any user
- **Parameters**: 
  - `id` (path parameter): User ID (positive integer)
- **Response**: 
  ```json
  {
    "message": "Successfully fetched user",
    "user": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "user",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T00:00:00.000Z"
    }
  }
  ```

### 2. Update User
- **URL**: `PUT /api/users/:id`
- **Authentication**: Required
- **Authorization**: 
  - Users can update their own information
  - Only admins can update any user
  - Only admins can change user roles
- **Parameters**:
  - `id` (path parameter): User ID (positive integer)
- **Body**:
  ```json
  {
    "name": "Updated Name (optional)",
    "email": "updated@example.com (optional)",
    "role": "admin or user (optional, admin only)"
  }
  ```
- **Response**:
  ```json
  {
    "message": "User updated successfully",
    "user": {
      "id": 1,
      "name": "Updated Name",
      "email": "updated@example.com",
      "role": "user",
      "createdAt": "2024-01-01T00:00:00.000Z",
      "updatedAt": "2024-01-01T12:00:00.000Z"
    }
  }
  ```

### 3. Delete User
- **URL**: `DELETE /api/users/:id`
- **Authentication**: Required
- **Authorization**: 
  - Users can delete their own account
  - Admins can delete any user account
- **Parameters**:
  - `id` (path parameter): User ID (positive integer)
- **Response**:
  ```json
  {
    "message": "User deleted successfully",
    "deletedUser": {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com",
      "role": "user"
    }
  }
  ```

## Error Responses

### Validation Errors (400 Bad Request)
```json
{
  "error": "Validation failed",
  "details": "Error description"
}
```

### Authentication Errors (401 Unauthorized)
```json
{
  "error": "Unauthorized",
  "message": "No token provided"
}
```

### Authorization Errors (403 Forbidden)
```json
{
  "error": "Forbidden",
  "message": "You can only update your own information"
}
```

### Not Found Errors (404 Not Found)
```json
{
  "error": "User not found"
}
```

### Conflict Errors (409 Conflict)
```json
{
  "error": "Email already exists"
}
```

## Validation Rules

### User ID
- Must be a positive integer
- Required for all operations

### Update User Schema
- `name`: 2-255 characters, trimmed (optional)
- `email`: Valid email format, max 255 characters, lowercase, trimmed (optional)
- `role`: Must be either "user" or "admin" (optional, admin only)
- At least one field must be provided for updates

## Security Features

1. **Authentication**: JWT token-based authentication
2. **Authorization**: Role-based and ownership-based access control
3. **Input Validation**: Comprehensive validation using Zod schemas
4. **Email Uniqueness**: Prevents duplicate email addresses
5. **Audit Logging**: All operations are logged with user context

## Implementation Files

- `src/services/users.services.js`: Business logic for user operations
- `src/controllers/users.controller.js`: HTTP request handling and validation
- `src/validations/users.validation.js`: Zod validation schemas
- `src/routes/users.routes.js`: Route definitions with authentication middleware
- `src/middleware/auth.middleware.js`: Authentication and authorization middleware
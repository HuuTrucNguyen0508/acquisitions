# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Architecture Overview

This is a Node.js/Express.js application with Docker containerization and Neon PostgreSQL database integration. The application follows a layered architecture pattern:

### Core Architecture
- **Entry Point**: `src/index.js` loads environment config and starts server
- **Server Setup**: `src/server.js` configures port and starts HTTP server
- **Application Layer**: `src/app.js` configures Express middleware, routes, and security
- **Database Layer**: Drizzle ORM with Neon PostgreSQL (both local and cloud support)
- **Security**: Arcjet integration for bot detection, rate limiting, and shield protection

### Database Configuration
- **Development**: Uses Neon Local via Docker (ephemeral branches)
- **Production**: Uses Neon Cloud with serverless driver
- **Multi-driver Support**: Automatically configures based on NODE_ENV
- **Connection**: `src/config/database.js` handles environment-specific configurations

### Project Structure Pattern
- Uses ES6 modules with `#` import maps for cleaner imports
- Follows MVC pattern: Controllers, Services, Routes, Models, Middleware
- Security-first approach with Helmet, CORS, and Arcjet middleware
- Centralized logging with Winston

## Development Commands

### Environment Setup
```bash
# Copy environment template (if needed)
cp .env.example .env.development

# Start development environment (recommended)
docker-compose -f docker-compose.dev.yml up --build

# Alternative: Use PowerShell script (Windows)
.\scripts\dev.ps1 start

# Alternative: Local development without Docker
pnpm install
NODE_ENV=development pnpm dev
```

### Database Operations
```bash
# Generate new migrations
docker-compose -f docker-compose.dev.yml exec app pnpm db:generate
# Or via script: .\scripts\dev.ps1 generate

# Run migrations
docker-compose -f docker-compose.dev.yml exec app pnpm db:migrate  
# Or via script: .\scripts\dev.ps1 migrate

# Open Drizzle Studio (database admin UI)
docker-compose -f docker-compose.dev.yml exec app pnpm db:studio
# Or via script: .\scripts\dev.ps1 studio
```

### Code Quality
```bash
# Lint code
pnpm lint

# Auto-fix linting issues
pnpm lint:fix

# Format code with Prettier
pnpm format

# Check formatting
pnpm format:check
```

### Development Workflow
```bash
# View application logs
docker-compose -f docker-compose.dev.yml logs -f app
# Or via script: .\scripts\dev.ps1 logs app

# Open shell in app container
docker-compose -f docker-compose.dev.yml exec app sh
# Or via script: .\scripts\dev.ps1 shell

# Stop development environment
docker-compose -f docker-compose.dev.yml down
# Or via script: .\scripts\dev.ps1 stop

# Full cleanup (removes volumes, networks, images)
.\scripts\dev.ps1 cleanup
```

### Production Deployment
```bash
# Build and run production containers
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

# With Nginx reverse proxy
docker-compose -f docker-compose.prod.yml --profile with-nginx up -d

# Production database migrations
docker-compose -f docker-compose.prod.yml exec app pnpm db:migrate
```

## Development Environment Details

### Required Environment Variables
The application requires these variables in `.env.development`:
- `NEON_API_KEY`: Your Neon API key from console.neon.tech
- `NEON_PROJECT_ID`: Project ID from Neon project settings
- `PARENT_BRANCH_ID`: Main branch ID for ephemeral development branches
- `DATABASE_URL`: Connection string (auto-configured for development)
- `ARCJET_KEY`: Security service API key (optional for development)

### Hot Reload Development
- Source code changes automatically restart the Node.js application
- Docker volumes mount `src/` directory for real-time updates
- Database schema changes require running migrations

### Security Middleware Stack
The application implements multiple security layers:
1. **Helmet**: Sets security headers
2. **CORS**: Cross-origin resource sharing configuration  
3. **Arcjet**: Bot detection, rate limiting, and attack protection
4. **Cookie Parser**: Secure cookie handling
5. **Morgan Logging**: Request logging with Winston integration

### Database Schema Management
- Uses Drizzle ORM with PostgreSQL
- Schema defined in `src/models/*.js` files
- Migrations generated with `drizzle-kit generate`
- Database introspection available via Drizzle Studio

### Import Path Resolution
The project uses Node.js import maps for cleaner imports:
- `#config/*` → `./src/config/*`
- `#models/*` → `./src/models/*`
- `#routes/*` → `./src/routes/*`
- `#services/*` → `./src/services/*`
- `#controllers/*` → `./src/controllers/*`
- `#middleware/*` → `./src/middleware/*`
- `#validations/*` → `./src/validations/*`
- `#utils/*` → `./src/utils/*`

## Key Configuration Files

- `package.json`: Dependencies, scripts, and import maps
- `drizzle.config.js`: Database ORM configuration
- `eslint.config.js`: Code linting rules (4-space indentation, single quotes)
- `docker-compose.dev.yml`: Development environment with Neon Local
- `docker-compose.prod.yml`: Production environment with health checks
- `Dockerfile`: Multi-stage build (development and production targets)

## PowerShell Development Scripts

The `scripts/dev.ps1` provides comprehensive development environment management:
- Validates Docker and environment requirements
- Creates ephemeral database branches automatically
- Provides health checks and detailed logging
- Handles cleanup of development resources

Use `.\scripts\dev.ps1 help` to see all available commands.
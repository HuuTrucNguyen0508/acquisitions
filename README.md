# Acquisitions App - Docker Setup with Neon Database

This application is configured to work with Neon Database in both development and production environments using Docker.

## Architecture Overview

- **Development**: Uses Neon Local via Docker for local database proxy with ephemeral branches
- **Production**: Uses Neon Cloud Database with serverless connection
- **Multi-driver Support**: Automatically configures Neon serverless driver for both environments

## Prerequisites

- Docker and Docker Compose installed
- Neon account and project setup
- Node.js 20+ (for local development without Docker)
- pnpm package manager

## Environment Configuration

### Development Environment

1. **Set up Neon credentials** in `.env.development`:

    ```bash
    # Copy the example file
    cp .env.example .env.development

    # Edit with your Neon credentials
    NEON_API_KEY=your_neon_api_key_here
    NEON_PROJECT_ID=your_neon_project_id_here
    PARENT_BRANCH_ID=your_parent_branch_id_here
    ```

2. **Get your Neon credentials**:
    - **API Key**: Go to [Neon Console](https://console.neon.tech) → Account Settings → API Keys
    - **Project ID**: Found in Project Settings → General
    - **Parent Branch ID**: Usually your main branch ID (found in Branches section)

### Production Environment

1. **Configure production environment** in `.env.production`:

    ```bash
    DATABASE_URL=postgres://username:password@ep-example-123456.us-east-1.aws.neon.tech/acquisitions?sslmode=require
    JWT_SECRET=your_production_jwt_secret_here
    ```

2. **Note**: In production deployments, inject these via your CI/CD pipeline or secrets management system.

## Development Setup

### Option 1: Docker Compose (Recommended)

1. **Start the development environment**:

    ```bash
    docker-compose -f docker-compose.dev.yml up --build
    ```

2. **The setup includes**:
    - Neon Local proxy at `localhost:5432`
    - Your app at `http://localhost:3000`
    - Hot-reload enabled for development
    - Ephemeral database branches (created/deleted with container lifecycle)

3. **Run database migrations**:

    ```bash
    # In another terminal
    docker-compose -f docker-compose.dev.yml exec app pnpm db:migrate
    ```

4. **Stop and cleanup**:
    ```bash
    docker-compose -f docker-compose.dev.yml down
    ```

### Option 2: Local Development (Without Docker)

1. **Install dependencies**:

    ```bash
    pnpm install
    ```

2. **Set up Neon Local separately**:

    ```bash
    docker run --name db \\
      -p 5432:5432 \\
      -e NEON_API_KEY=your_neon_api_key \\
      -e NEON_PROJECT_ID=your_neon_project_id \\
      -e PARENT_BRANCH_ID=your_parent_branch_id \\
      neondatabase/neon_local:latest
    ```

3. **Run the application**:
    ```bash
    NODE_ENV=development pnpm dev
    ```

## Production Deployment

### Basic Production Setup

1. **Build and run production container**:

    ```bash
    # Build the production image
    docker-compose -f docker-compose.prod.yml build

    # Start production services
    docker-compose -f docker-compose.prod.yml up -d
    ```

2. **With environment variables**:

    ```bash
    # Set production environment variables
    export DATABASE_URL="postgres://username:password@ep-example-123456.us-east-1.aws.neon.tech/acquisitions?sslmode=require"
    export JWT_SECRET="your_production_jwt_secret"

    # Start production services
    docker-compose -f docker-compose.prod.yml up -d
    ```

### Production with Nginx (Optional)

To include nginx reverse proxy:

```bash
docker-compose -f docker-compose.prod.yml --profile with-nginx up -d
```

### CI/CD Deployment Example

```yaml
# Example GitHub Actions workflow
deploy:
    runs-on: ubuntu-latest
    steps:
        - uses: actions/checkout@v3
        - name: Deploy to production
          env:
              DATABASE_URL: ${{ secrets.DATABASE_URL }}
              JWT_SECRET: ${{ secrets.JWT_SECRET }}
          run: |
              docker-compose -f docker-compose.prod.yml up -d --build
```

## Database Management

### Development Database Operations

```bash
# Generate migrations
docker-compose -f docker-compose.dev.yml exec app pnpm db:generate

# Run migrations
docker-compose -f docker-compose.dev.yml exec app pnpm db:migrate

# Open Drizzle Studio
docker-compose -f docker-compose.dev.yml exec app pnpm db:studio
```

### Production Database Operations

```bash
# Run migrations in production
docker-compose -f docker-compose.prod.yml exec app pnpm db:migrate
```

## Key Features

### Development Features

- **Ephemeral Branches**: Each container start creates a fresh database branch
- **Hot Reload**: Source code changes automatically restart the application
- **Neon Local**: Local proxy eliminates the need to change connection strings
- **Docker Networking**: Services communicate via internal Docker network

### Production Features

- **Health Checks**: Automatic container health monitoring
- **Resource Limits**: CPU and memory constraints for stability
- **Logging**: Structured logging with rotation
- **Security**: Non-root user and minimal attack surface
- **Multi-stage Build**: Optimized production images

## Connection String Reference

### Development (Neon Local)

```
postgres://neon:npg@neon-local:5432/acquisitions?sslmode=require
```

### Production (Neon Cloud)

```
postgres://username:password@ep-example-123456.us-east-1.aws.neon.tech/acquisitions?sslmode=require
```

## Troubleshooting

### Common Issues

1. **Neon Local connection fails**:
    - Ensure NEON_API_KEY, NEON_PROJECT_ID, and PARENT_BRANCH_ID are correct
    - Check Docker network connectivity
    - Verify the Neon Local container is healthy

2. **Database migrations fail**:
    - Ensure DATABASE_URL is accessible
    - Check network connectivity between app and database
    - Verify database permissions

3. **Hot reload not working in development**:
    - Ensure source code volumes are properly mounted
    - Check file permissions (especially on Windows/Mac)

### Debugging

1. **View logs**:

    ```bash
    # Development
    docker-compose -f docker-compose.dev.yml logs -f app

    # Production
    docker-compose -f docker-compose.prod.yml logs -f app
    ```

2. **Access container shell**:

    ```bash
    # Development
    docker-compose -f docker-compose.dev.yml exec app sh

    # Production
    docker-compose -f docker-compose.prod.yml exec app sh
    ```

3. **Check health status**:
    ```bash
    docker-compose -f docker-compose.dev.yml ps
    ```

## Security Considerations

- Never commit `.env` files with real credentials
- Use secrets management in production (e.g., Docker Secrets, Kubernetes Secrets)
- Regularly rotate API keys and database passwords
- Use HTTPS in production with proper SSL certificates
- Keep Docker images updated with security patches

## Performance Optimization

### Development

- Use volumes for node_modules to avoid repeated installations
- Enable Docker BuildKit for faster builds
- Consider using Docker layer caching

### Production

- Multi-stage builds minimize image size
- Health checks ensure service reliability
- Resource limits prevent resource exhaustion
- Log rotation prevents disk space issues

## File Structure

```
├── Dockerfile                 # Multi-stage Docker configuration
├── docker-compose.dev.yml     # Development environment
├── docker-compose.prod.yml    # Production environment
├── .env.development          # Development environment variables
├── .env.production           # Production environment variables
├── .env.example              # Environment template
├── .dockerignore             # Docker build exclusions
├── .gitignore                # Git exclusions
├── src/
│   ├── config/
│   │   └── database.js       # Database configuration with multi-driver support
│   └── ...
└── README.md                 # This file
```

## Additional Resources

- [Neon Documentation](https://neon.com/docs)
- [Neon Local Documentation](https://neon.com/docs/local/neon-local)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Drizzle ORM Documentation](https://orm.drizzle.team/)

---

For support or questions, please refer to the project documentation or contact the development team.

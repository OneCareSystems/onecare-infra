# OneCare Infrastructure

Infrastructure and deployment configuration for the **OneCare Clinic Management System**.

This repository provides a centralized Docker Compose environment for running and deploying the complete OneCare application stack.

The OneCare system consists of five services:

- React Frontend
- Spring Boot Backend
- MySQL Database
- Redis Cache
- Django Chatbot

The infrastructure repository supports two environments:

1. **Local Development:** Developers can run the complete application using Docker Compose and local application repositories.
2. **AWS EC2 Deployment:** Application Docker images are manually built, pushed to AWS Elastic Container Registry (ECR), and deployed to an AWS EC2 instance using Docker Compose.

Currently, image building, publishing and EC2 deployment are performed manually. GitHub Actions automation and AWS OIDC integration are planned as future improvements.

---

# 1. Architecture

## Application Architecture

OneCare uses Docker Compose to manage communication between its five application services.

```text
                     OneCare Application
                            |
                       Docker Compose
                            |
              +-------------+-------------+
              |             |             |
              v             v             v
          Frontend       Backend         MySQL
           React        Spring Boot       8.4
              |             |
              |        +----+-----+
              |        |          |
              |        v          v
              |      Redis     Chatbot
              |       7        Django
              |                5 + DRF
              +--------------------+
```

### Services

| Service | Technology | Development Port | Purpose |
|---|---|---:|---|
| Frontend | React + Vite | `3000` | User interface |
| Backend | Spring Boot + Java 21 | `8080` | REST API and business logic |
| Database | MySQL 8.4 | `3306` | Persistent application data |
| Cache | Redis 7 | `6379` | Caching and temporary data |
| Chatbot | Django 5 + DRF | `8000` | AI chat service |

In the EC2 deployment, only the frontend is publicly exposed. Backend, chatbot, MySQL and Redis communicate through the internal Docker network.

---

# 2. Repository Structure

The OneCare project consists of four separate Git repositories.

All repositories should be cloned into the same parent directory for local development.

```text
OneCare/
│
├── onecare-frontend/
│   ├── Dockerfile
│   ├── Dockerfile.prod
│   ├── package.json
│   └── src/
│
├── onecare-backend/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
│
├── onecare-chatbot/
│   ├── Dockerfile
│   ├── manage.py
│   ├── requirements.txt
│   └── onecare_chat/
│
└── onecare-infra/
    ├── .github/
    │   └── workflows/
    │       └── ci.yml
    │
    ├── scripts/
    │
    ├── docker-compose.yml
    ├── docker-compose.prod.yml
    ├── docker-compose.ec2ecr.yml
    │
    ├── .env.example
    ├── .gitignore
    └── README.md
```

### Repository Responsibilities

| Repository | Responsibility |
|---|---|
| `onecare-frontend` | React frontend development and Docker image building |
| `onecare-backend` | Spring Boot backend development and Docker image building |
| `onecare-chatbot` | Django chatbot development and Docker image building |
| `onecare-infra` | Local Docker Compose, AWS deployment configuration and infrastructure management |

The infrastructure repository centralizes deployment configuration for the complete application.

---

# 3. Prerequisites

Install the following software before starting local development:

- Git
- Docker Desktop
- Docker Compose V2

Docker Compose is included with current versions of Docker Desktop.

Verify the installation:

```bash
docker --version
```

```bash
docker compose version
```

For AWS deployment, the following are also required:

- AWS Account
- AWS CLI
- AWS Elastic Container Registry (ECR)
- AWS Elastic Compute Cloud (EC2)
- AWS IAM
- Docker Engine
- Docker Compose V2

---

# 4. Local Development Environment

The local development environment builds application images directly from their respective repositories.

## 4.1 Clone the Repositories

Clone all four repositories into the same parent directory.

```bash
git clone https://github.com/OneCareSystems/onecare-frontend.git

git clone https://github.com/OneCareSystems/onecare-backend.git

git clone https://github.com/OneCareSystems/onecare-chatbot.git

git clone https://github.com/OneCareSystems/onecare-infra.git
```

The resulting structure should be:

```text
OneCare/
├── onecare-frontend/
├── onecare-backend/
├── onecare-chatbot/
└── onecare-infra/
```

**Important:** Do not place the repositories inside each other. They must be sibling directories.

## 4.2 Navigate to the Infrastructure Repository

```bash
cd onecare-infra
```

## 4.3 Create the Environment File

Copy the example environment file.

### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

### Linux / macOS

```bash
cp .env.example .env
```

Update the required environment variables.

Example:

```env
DB_HOST=db
DB_PORT=3306
DB_NAME=onecare
DB_USER=onecare
DB_PASSWORD=change_me
DB_ROOT_PASSWORD=change_root_password

BACKEND_PORT=8080
FRONTEND_PORT=3000
CHATBOT_PORT=8000

CHATBOT_DB_PASSWORD=chatbot_dev_pw

CHATBOT_SERVICE_TOKEN=replace_with_secure_token

REDIS_HOST=cache
REDIS_PORT=6379

JWT_SECRET=replace_with_secure_secret

JWT_ACCESS_TOKEN_EXPIRY=1800000
JWT_REFRESH_TOKEN_EXPIRY=604800000
```

Additional application-specific variables may be required depending on the backend and chatbot configuration.

### Security

Never commit `.env` to Git.

The `.gitignore` file should contain:

```gitignore
.env
.env.ec2ecr
```

Only example configuration files should be committed.

---

# 5. Start the Local Environment

From the `onecare-infra` directory, execute:

```bash
docker compose up --build
```

Docker Compose will:

1. Build the backend Docker image.
2. Build the chatbot Docker image.
3. Build the frontend Docker image.
4. Pull the MySQL image if unavailable locally.
5. Pull the Redis image if unavailable locally.
6. Create the Docker network.
7. Create the MySQL persistent volume.
8. Start MySQL.
9. Wait for MySQL to become healthy.
10. Start Redis.
11. Start the Spring Boot backend.
12. Start the Django chatbot after its database dependencies are ready.
13. Run chatbot database migrations.
14. Start the frontend after its required dependencies become healthy.

Docker Compose manages the complete application environment.

Developers do not need to manually execute:

```bash
mvn spring-boot:run
```

or:

```bash
npm run dev
```

or manually start MySQL and Redis.

## 5.1 Run in Background

```bash
docker compose up --build -d
```

## 5.2 Check Running Services

```bash
docker compose ps
```

Expected services:

```text
onecare-frontend
onecare-backend
onecare-chatbot
onecare-db
onecare-cache
```

## 5.3 Access the Application

Frontend:

```text
http://localhost:3000
```

Backend:

```text
http://localhost:8080
```

Backend health:

```text
http://localhost:8080/actuator/health
```

Chatbot:

```text
http://localhost:8000
```

Chatbot health:

```text
http://localhost:8000/api/chatbot/health/
```

MySQL:

```text
localhost:3306
```

Redis:

```text
localhost:6379
```

MySQL and Redis are infrastructure services and are normally accessed by the backend rather than directly through a browser.

---

# 6. Service Communication

Docker Compose provides internal DNS resolution using service names.

Containers should communicate using Docker service names rather than `localhost`.

### Backend to MySQL

```text
jdbc:mysql://db:3306/onecare
```

### Backend to Redis

```text
cache:6379
```

### Backend to Chatbot

```text
http://chatbot:8000
```

Do not use:

```text
localhost:3306
```

or:

```text
localhost:6379
```

from inside the backend container.

Inside a Docker container, `localhost` refers to that same container.

The Compose service names are:

```text
frontend
backend
db
cache
chatbot
```

---

# 7. Database Persistence

MySQL uses a named Docker volume:

```text
onecare-mysql-data
```

Database data persists even when containers are removed.

To stop the environment:

```bash
docker compose down
```

The database volume remains intact.

To remove all containers and database data:

```bash
docker compose down -v
```

**Warning:** This permanently deletes the MySQL data stored in the volume.

Use this command only when a fresh database initialization is intentionally required.

### Chatbot Database

The chatbot uses its own database schema:

```text
Database: onecare_chatbot
User: chatbot_app
```

It does not use the main application database for its dedicated Django data.

Both schemas and their database users are created through:

```text
docker/mysql/init/01_schemas_and_users.sql
```

These initialization scripts execute only when MySQL initializes a new data volume.

An existing database volume must already contain the required chatbot schema and account.

---

# 8. Docker Compose Configuration

OneCare uses separate Docker Compose configurations for different environments.

| File | Purpose |
|---|---|
| `docker-compose.yml` | Local development |
| `docker-compose.prod.yml` | Production-like local testing |
| `docker-compose.ec2ecr.yml` | AWS EC2 deployment using ECR images |

## 8.1 Local Development Compose

The base Compose file builds application images from local repositories.

Example:

```yaml
backend:
  build:
    context: ../onecare-backend

frontend:
  build:
    context: ../onecare-frontend

chatbot:
  build:
    context: ../onecare-chatbot
```

Developers can rebuild application images whenever source code changes.

## 8.2 Production-like Compose

The production-like Compose configuration provides:

- Frontend served using unprivileged Nginx.
- No frontend development source bind mounts.
- Same-origin API proxying.
- Internal backend, chatbot, MySQL and Redis communication.
- Backend health checks.
- Frontend startup after backend health checks succeed.
- Runtime frontend configuration through `/config.json`.

Run the production-like environment locally:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  build
```

Start:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  up -d
```

The backend uses the `staging` profile by default in this configuration.

For a production host, configure:

```env
SPRING_PROFILES_ACTIVE=prod
```

TLS/HTTPS should terminate at an edge proxy or load balancer rather than inside the application containers.

---

# 9. AWS ECR and EC2 Deployment Architecture

OneCare uses AWS Elastic Container Registry (ECR) to store the Docker images of its three application services.

The three application images are:

1. Frontend
2. Backend
3. Chatbot

Currently, these images are manually built and pushed to their respective ECR repositories.

The EC2 instance pulls the published images and runs the complete application using Docker Compose.

## 9.1 AWS Region

OneCare currently uses:

```text
ap-southeast-2
```

Region:

```text
Asia Pacific (Sydney)
```

All three application ECR repositories should be maintained in this region.

## 9.2 ECR Repositories

OneCare uses three separate ECR repositories.

| Application | ECR Repository |
|---|---|
| Frontend | `onecare-frontend` |
| Backend | `onecare-backend` |
| Chatbot | `onecare-chatbot` |

Repository URI format:

```text
AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-frontend

AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-backend

AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-chatbot
```

Recommended repository settings:

- Image tag mutability: Immutable
- Image scanning: Enabled
- Encryption: Enabled
- Lifecycle policy: Retain recent deployment images and remove obsolete images according to an approved retention policy.

The existing `onecare-backend` ECR repository should be retained.

## 9.3 Current Deployment Architecture

```text
       FRONTEND REPOSITORY
       BACKEND REPOSITORY
       CHATBOT REPOSITORY
                |
                v
       Manually Build Docker Images
                |
                v
       Manually Push Images to ECR
                |
                v
          AWS ECR Registry
                |
                v
          AWS EC2 Instance
                |
          Manual EC2 Connection
                |
                v
        Manually Execute Docker Compose
                |
       +--------+--------+
       |        |        |
       v        v        v
    Frontend Backend  Chatbot
                |
           +----+----+
           |         |
           v         v
         MySQL     Redis
```

### Current Deployment Responsibilities

| Component | Current Approach |
|---|---|
| Frontend image building | Manual |
| Backend image building | Manual |
| Chatbot image building | Manual |
| Image publishing | Manual push to ECR |
| Container registry | AWS ECR |
| EC2 deployment | Manual |
| Container orchestration | Docker Compose |
| Image updates | Manual pull and container recreation |
| GitHub OIDC | Not implemented |
| Automated EC2 deployment | Not implemented |

## 9.4 Docker Image Tagging

Use Git commit SHA-based image tags.

Example:

```text
onecare-frontend:sha-a123456

onecare-backend:sha-b123456

onecare-chatbot:sha-c123456
```

Avoid using `latest` for deployment.

Immutable SHA tags provide:

- Version traceability.
- Reproducible deployments.
- Easier rollback.
- Identification of deployed application versions.

Each repository has its own commit SHA because the three application repositories are independent.

---

# 10. Manual Docker Image Publishing

Currently, application Docker images are built and pushed to AWS ECR manually.

Each application has its own ECR repository.

## 10.1 AWS Authentication

Authenticate using your currently configured AWS authentication method.

Verify AWS CLI access:

```bash
aws sts get-caller-identity
```

Verify the region:

```bash
aws configure get region
```

The required region is:

```text
ap-southeast-2
```

## 10.2 Authenticate Docker with ECR

Execute:

```bash
aws ecr get-login-password \
  --region ap-southeast-2 \
  | docker login \
      --username AWS \
      --password-stdin AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com
```

Replace `AWS_ACCOUNT_ID` with your AWS account ID.

## 10.3 Build and Push Frontend Image

Navigate to the frontend repository:

```bash
cd onecare-frontend
```

Build the production image:

```bash
docker build \
  -f Dockerfile.prod \
  -t onecare-frontend:sha-a123456 .
```

Tag the image for ECR:

```bash
docker tag \
  onecare-frontend:sha-a123456 \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-frontend:sha-a123456
```

Push:

```bash
docker push \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-frontend:sha-a123456
```

Use the appropriate Dockerfile and build arguments required by the actual frontend production configuration.

## 10.4 Build and Push Backend Image

Navigate to the backend repository:

```bash
cd ../onecare-backend
```

Build:

```bash
docker build \
  -t onecare-backend:sha-b123456 .
```

Tag:

```bash
docker tag \
  onecare-backend:sha-b123456 \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-backend:sha-b123456
```

Push:

```bash
docker push \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-backend:sha-b123456
```

## 10.5 Build and Push Chatbot Image

Navigate to the chatbot repository:

```bash
cd ../onecare-chatbot
```

Build:

```bash
docker build \
  -t onecare-chatbot:sha-c123456 .
```

Tag:

```bash
docker tag \
  onecare-chatbot:sha-c123456 \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-chatbot:sha-c123456
```

Push:

```bash
docker push \
  AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com/onecare-chatbot:sha-c123456
```

Replace the example SHA values with the actual commit identifiers of the respective repositories.

### Verify Published Images

Run:

```bash
aws ecr describe-images \
  --repository-name onecare-frontend \
  --region ap-southeast-2
```

```bash
aws ecr describe-images \
  --repository-name onecare-backend \
  --region ap-southeast-2
```

```bash
aws ecr describe-images \
  --repository-name onecare-chatbot \
  --region ap-southeast-2
```

All three images should appear in their respective repositories before deployment.

---

# 11. EC2 Deployment Configuration

The AWS EC2 instance acts as the application deployment server.

It pulls prebuilt images from ECR and manages containers through Docker Compose.

It does not need to build application images.

## 11.1 EC2 Instance

Current staging configuration:

| Configuration | Value |
|---|---|
| Instance Name | `onecare-staging` |
| Region | `ap-southeast-2` |
| Operating System | Ubuntu |
| Instance Type | `c7i-flex.large` |
| Deployment Method | Docker Compose |
| Container Registry | AWS ECR |

## 11.2 Install Required Software

Install:

- Docker Engine
- Docker Compose V2
- AWS CLI

Verify:

```bash
docker --version
```

```bash
docker compose version
```

```bash
aws --version
```

## 11.3 Create Deployment Directory

Create:

```bash
sudo mkdir -p /opt/onecare
```

The directory structure should be:

```text
/opt/onecare/
│
├── docker-compose.ec2ecr.yml
│
├── .env.ec2ecr
│
└── docker/
    └── mysql/
        └── init/
            └── 01_schemas_and_users.sql
```

The Compose file and database initialization scripts are provided by the infrastructure repository.

The production environment file is created directly on EC2 and must not be committed to Git.

## 11.4 EC2 Authentication with AWS ECR

Use the AWS authentication method currently configured on your EC2 instance.

If an EC2 IAM instance role is attached, it should have read-only access to the three ECR repositories.

Required ECR permissions include:

```text
ecr:GetAuthorizationToken
ecr:BatchCheckLayerAvailability
ecr:GetDownloadUrlForLayer
ecr:BatchGetImage
```

Verify AWS identity:

```bash
aws sts get-caller-identity
```

Authenticate Docker:

```bash
aws ecr get-login-password \
  --region ap-southeast-2 \
  | docker login \
      --username AWS \
      --password-stdin AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com
```

---

# 12. EC2 Environment Configuration

Create the following file on EC2:

```text
/opt/onecare/.env.ec2ecr
```

Example:

```env
AWS_ACCOUNT_ID=YOUR_AWS_ACCOUNT_ID
AWS_REGION=ap-southeast-2

FRONTEND_IMAGE_TAG=sha-a123456
BACKEND_IMAGE_TAG=sha-b123456
CHATBOT_IMAGE_TAG=sha-c123456

MYSQL_DATABASE=onecare
MYSQL_USER=onecare
MYSQL_PASSWORD=YOUR_SECURE_PASSWORD
MYSQL_ROOT_PASSWORD=YOUR_SECURE_ROOT_PASSWORD

CHATBOT_DB_USER=chatbot_app
CHATBOT_DB_PASSWORD=YOUR_SECURE_CHATBOT_DB_PASSWORD

JWT_SECRET=YOUR_SECURE_JWT_SECRET

DJANGO_SECRET_KEY=YOUR_SECURE_DJANGO_SECRET

CHATBOT_SERVICE_TOKEN=YOUR_SECURE_SERVICE_TOKEN

BACKUP_ENCRYPTION_KEY=YOUR_BACKUP_ENCRYPTION_KEY

COLUMN_ENCRYPTION_KEY=

SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=

LLM_API_KEY=
GROQ_API_KEY=

SPRING_PROFILES_ACTIVE=staging
```

Retain all other required application-specific environment variables from the existing EC2 deployment configuration.

The variable names must match the references in the actual Compose configuration and application settings.

### Security Requirements

- Use strong, unique production secrets.
- Do not reuse local development credentials.
- Never commit `.env.ec2ecr`.
- Restrict file access on EC2.
- Do not expose database or cache ports publicly.
- Use a secure secrets-management solution for future production improvements.

---

# 13. EC2 Docker Compose Deployment

The file:

```text
docker-compose.ec2ecr.yml
```

is responsible for deploying the three prebuilt application images from ECR.

Unlike the local development Compose file, it must not contain application source build contexts.

## 13.1 Application Image Configuration

Frontend:

```yaml
frontend:
  image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/onecare-frontend:${FRONTEND_IMAGE_TAG}
```

Backend:

```yaml
backend:
  image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/onecare-backend:${BACKEND_IMAGE_TAG}
```

Chatbot:

```yaml
chatbot:
  image: ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/onecare-chatbot:${CHATBOT_IMAGE_TAG}
```

The actual Compose file must preserve:

- Existing application environment variables.
- MySQL database configuration.
- Redis configuration.
- Backend health checks.
- Chatbot health checks.
- Chatbot migration startup.
- Persistent database volumes.
- Internal Docker networking.
- Service startup dependencies.
- Frontend runtime configuration.

## 13.2 Network and Port Exposure

For EC2 deployment:

| Service | Container Port | Public Access |
|---|---:|---|
| Frontend | 8080 | Yes, through port 80 |
| Backend | 8080 | No |
| Chatbot | 8000 | No |
| MySQL | 3306 | No |
| Redis | 6379 | No |

The frontend acts as the public entry point and proxies API requests to the backend.

The backend communicates with the chatbot through the internal Docker network.

MySQL and Redis remain private.

---

# 14. Manual EC2 Deployment Process

Currently, deployments are initiated manually by connecting to the EC2 instance.

After all three images have been successfully published to ECR, connect to EC2 using SSH.

Navigate to the deployment directory:

```bash
cd /opt/onecare
```

## 14.1 Authenticate with ECR

```bash
aws ecr get-login-password \
  --region ap-southeast-2 \
  | docker login \
      --username AWS \
      --password-stdin AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com
```

## 14.2 Update Image Tags

Edit:

```text
.env.ec2ecr
```

Update the image tags:

```env
FRONTEND_IMAGE_TAG=sha-a123456
BACKEND_IMAGE_TAG=sha-b123456
CHATBOT_IMAGE_TAG=sha-c123456
```

Use the actual tags that were pushed to ECR.

## 14.3 Pull Application Images

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  pull
```

This downloads the specified frontend, backend and chatbot images.

## 14.4 Start the Application

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  up -d --no-build
```

Docker Compose starts or recreates the containers using the selected ECR images.

The `--no-build` option ensures EC2 does not attempt to build application images locally.

## 14.5 Verify Running Services

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  ps
```

## 14.6 View Logs

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  logs -f
```

Backend logs:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  logs -f backend
```

Frontend logs:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  logs -f frontend
```

Chatbot logs:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  logs -f chatbot
```

---

# 15. Deployment and Rollback Strategy

OneCare uses immutable SHA-based image tags.

Each deployment should record the versions currently running.

Example:

```text
Current Deployment:

Frontend: sha-a123456
Backend:  sha-b123456
Chatbot:  sha-c123456
```

A new deployment might use:

```text
New Deployment:

Frontend: sha-a456789
Backend:  sha-b456789
Chatbot:  sha-c456789
```

If the new deployment fails, restore the previous image tags in `.env.ec2ecr`.

Then execute:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  pull
```

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  up -d --no-build
```

This restores the previous application image versions.

**Important:** Application image rollback does not automatically reverse database schema changes. Database backups and backward-compatible migration practices must be maintained.

---

# 16. Future CI/CD Automation

Automating Docker image publishing and EC2 deployment through GitHub Actions is planned as a future infrastructure improvement.

The current manual deployment process will remain in place until the AWS configuration and authentication requirements are resolved.

## 16.1 Planned GitHub Actions Architecture

```text
       FRONTEND REPOSITORY
       BACKEND REPOSITORY
       CHATBOT REPOSITORY
                |
                v
          GitHub Actions
                |
          CI Quality Checks
                |
                v
         Build Docker Images
                |
                v
         AWS OIDC Authentication
                |
                v
          Push Images to ECR
                |
                v
            AWS ECR
                |
                v
         onecare-infra
                |
                v
       Automated EC2 Deployment
                |
                v
          Docker Compose
```

## 16.2 Planned GitHub OIDC Integration

GitHub Actions will eventually authenticate with AWS using OpenID Connect (OIDC).

The planned configuration includes:

1. Create a GitHub Actions OIDC identity provider in AWS IAM.
2. Create an IAM role for GitHub Actions.
3. Configure the IAM trust policy for the authorized OneCare repositories.
4. Grant the required ECR publishing permissions.
5. Configure the role ARN in GitHub repository variables.
6. Update the application CI workflows to authenticate through OIDC.

GitHub OIDC is currently **not implemented** because of an outstanding AWS account configuration issue.

Until the issue is resolved, image building and publishing will continue manually.

## 16.3 Planned Image Publishing Workflow

Each application repository will maintain its own CI/CD workflow.

| Repository | Planned Responsibility |
|---|---|
| `onecare-frontend` | Build, test, scan and publish frontend image |
| `onecare-backend` | Build, test, scan and publish backend image |
| `onecare-chatbot` | Build, test, scan and publish chatbot image |

Planned branch strategy:

| GitHub Event | CI Checks | Docker Build | ECR Publishing |
|---|---|---|---|
| Pull request to `develop` | Yes | Yes | No |
| Merge/push to `develop` | Yes | Yes | Yes |
| Pull request to `main` | Yes | Yes | No |
| Merge/push to `main` | Yes | Yes | Yes |

The default branch for all application repositories is currently `develop`.

## 16.4 Planned Automated EC2 Deployment

After ECR image publishing is automated, the infrastructure repository will introduce:

```text
.github/workflows/deploy.yml
```

The planned deployment workflow will:

1. Accept the three application image SHA tags.
2. Validate the image versions.
3. Connect to EC2.
4. Update the image tags in the EC2 environment file.
5. Pull images from ECR.
6. Execute Docker Compose.
7. Verify application health.
8. Restore previous image versions if deployment fails.

Initially, deployment will remain manually triggered through GitHub Actions, even after image publishing automation is introduced.

Automatic deployment after every image push can be considered as a later improvement.

---

# 17. Deployment Implementation Roadmap

The OneCare deployment implementation is divided into three phases.

| Phase | Task | Status |
|---|---|---|
| Phase 1 | Manually build three application images | Current |
| Phase 1 | Manually push images to AWS ECR | Current |
| Phase 1 | Manually deploy images to EC2 using Docker Compose | Current |
| Phase 2 | Resolve AWS account configuration issue | Pending |
| Phase 2 | Configure GitHub OIDC | Pending |
| Phase 2 | Automate frontend ECR publishing | Planned |
| Phase 2 | Automate backend ECR publishing | Planned |
| Phase 2 | Automate chatbot ECR publishing | Planned |
| Phase 3 | Create infrastructure deployment workflow | Planned |
| Phase 3 | Automate EC2 deployment through GitHub Actions | Planned |
| Phase 3 | Implement automated deployment verification and rollback | Planned |

This phased approach allows OneCare to deploy and test the application before completing the full CI/CD implementation.

---

# 18. Environment Variables

The following table describes the primary environment variables used by the infrastructure.

| Variable | Description |
|---|---|
| `DB_HOST` | MySQL service hostname |
| `DB_PORT` | MySQL port |
| `DB_NAME` | Main application database |
| `DB_USER` | Main database username |
| `DB_PASSWORD` | Main database password |
| `DB_ROOT_PASSWORD` | MySQL root password |
| `MYSQL_DATABASE` | MySQL initialization database |
| `MYSQL_USER` | MySQL application user |
| `MYSQL_PASSWORD` | MySQL application password |
| `MYSQL_ROOT_PASSWORD` | MySQL root password |
| `BACKEND_PORT` | Backend host port |
| `FRONTEND_PORT` | Frontend host port |
| `CHATBOT_PORT` | Chatbot host port |
| `CHATBOT_DB_USER` | Dedicated chatbot database user |
| `CHATBOT_DB_PASSWORD` | Dedicated chatbot database password |
| `CHATBOT_SERVICE_TOKEN` | Spring Boot to Django authentication token |
| `DJANGO_SECRET_KEY` | Django signing secret |
| `REDIS_HOST` | Redis service hostname |
| `REDIS_PORT` | Redis port |
| `JWT_SECRET` | JWT signing secret |
| `JWT_ACCESS_TOKEN_EXPIRY` | Access token expiry |
| `JWT_REFRESH_TOKEN_EXPIRY` | Refresh token expiry |
| `SPRING_PROFILES_ACTIVE` | Active Spring profile |
| `BACKUP_ENCRYPTION_KEY` | AES-256-GCM backup encryption key |
| `COLUMN_ENCRYPTION_KEY` | Optional column encryption key |
| `SMTP_HOST` | SMTP server |
| `SMTP_PORT` | SMTP server port |
| `SMTP_USERNAME` | SMTP account username |
| `SMTP_PASSWORD` | SMTP account password |
| `RUNTIME_API_BASE_URL` | Frontend runtime API base URL |
| `AWS_ACCOUNT_ID` | AWS account ID |
| `AWS_REGION` | AWS region |
| `FRONTEND_IMAGE_TAG` | Frontend ECR image tag |
| `BACKEND_IMAGE_TAG` | Backend ECR image tag |
| `CHATBOT_IMAGE_TAG` | Chatbot ECR image tag |
| `LLM_API_KEY` | LLM provider API key |
| `GROQ_API_KEY` | Groq API key |

The exact variables required depend on the Compose configuration and application settings.

---

# 19. Useful Docker Commands

### List running containers

```bash
docker ps
```

### List all containers

```bash
docker ps -a
```

### List Docker images

```bash
docker images
```

### Check Compose configuration

```bash
docker compose config
```

### View all logs

```bash
docker compose logs
```

### Follow all logs

```bash
docker compose logs -f
```

### Stop the environment

```bash
docker compose down
```

### Remove containers and volumes

```bash
docker compose down -v
```

Use the last command carefully because it deletes persistent database data.

## Upgrading an existing deployment to DDP-#49

The backend now boots a packaged profile (`SPRING_PROFILES_ACTIVE`, `dev` in
the base layer, `staging` in the prod-like layer) and healthchecks against
`/actuator/health`. Before the next `up` on a host whose `.env` predates this
ticket:

1. Add `BACKUP_ENCRYPTION_KEY` to the host `.env` (`openssl rand -base64 32`)
   — compose refuses to start without it (`:?` gate).
2. Add `SMTP_HOST`/`SMTP_PORT`/`SMTP_USERNAME`/`SMTP_PASSWORD` (replacing the
   old `SPRING_MAIL_USERNAME`/`SPRING_MAIL_PASSWORD`) — optional, but the
   stack is unhealthy-free without them (health reports `DEGRADED`).
3. Rebuild the backend image once (`docker compose build backend`) after the
   backend repository contains the DDP-#49 actuator/profile changes — an
   image without `/actuator/health` fails the healthcheck and (in the
   prod-like layer) blocks the frontend.
4. Staging hosts: `scripts/deploy-staging.sh` enforces
   `SPRING_PROFILES_ACTIVE=staging` in the host `.env` automatically.

---

# 20. Troubleshooting

## Port Already in Use

If port `3000` or `8080` is already being used, update the corresponding environment variable.

Example:

```env
FRONTEND_PORT=3001
BACKEND_PORT=8081
```

The internal container ports remain unchanged.

## Backend Cannot Connect to MySQL

Check service status:

```bash
docker compose ps
```

Check MySQL logs:

```bash
docker compose logs db
```

The backend should use:

```text
db:3306
```

not:

```text
localhost:3306
```

## Backend Health Check Fails

Check:

```bash
docker compose logs backend
```

Verify:

```text
/actuator/health
```

The backend health endpoint returns HTTP 200 for `UP` and `DEGRADED`.

An optional integration such as SMTP should not prevent the backend from being considered healthy.

MySQL or Redis failures return HTTP 503 and should be investigated.

## Frontend Cannot Connect to Backend

Verify that the backend is running.

Check the frontend runtime API configuration and the Nginx `/api` proxy.

In the EC2 environment, browser requests should use the frontend's same-origin API route rather than exposing the backend directly.

## EC2 Cannot Pull Images from ECR

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

Authenticate Docker:

```bash
aws ecr get-login-password \
  --region ap-southeast-2 \
  | docker login \
      --username AWS \
      --password-stdin AWS_ACCOUNT_ID.dkr.ecr.ap-southeast-2.amazonaws.com
```

Verify that the image exists:

```bash
aws ecr describe-images \
  --repository-name onecare-backend \
  --region ap-southeast-2
```

Also verify that the requested SHA tag exists.

## Container Fails After Deployment

Check:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  ps
```

Then:

```bash
docker compose \
  --env-file .env.ec2ecr \
  -f docker-compose.ec2ecr.yml \
  logs -f
```

Investigate the failing service before attempting another deployment.

---

# 21. CI – Infrastructure Repository

The infrastructure repository maintains:

```text
.github/workflows/ci.yml
```

The CI workflow validates Docker Compose configurations.

The validation process includes:

1. Validate the local Docker Compose configuration.
2. Validate the production-like Compose configuration.
3. Validate the EC2 ECR Compose configuration.
4. Check that required environment variables are documented.
5. Check for hard-coded secrets in Compose files.
6. Verify that the Compose configurations can be parsed successfully.

Example local validation:

```bash
docker compose \
  --env-file .env.example \
  config --quiet
```

Production-like validation:

```bash
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  --env-file .env.example \
  config --quiet
```

EC2 ECR configuration validation should use an appropriate example environment file containing non-secret placeholder values.

CI validates configuration only. It does not deploy to EC2 during pull requests.

---

# 22. Security Notes

Security is an important part of the OneCare infrastructure.

Follow these requirements:

- Never commit `.env` or `.env.ec2ecr`.
- Never commit production secrets.
- Use secure AWS authentication.
- Restrict ECR access to authorized repositories.
- Use immutable image tags.
- Enable ECR image scanning.
- Use strong JWT and Django secrets.
- Use secure AES-256-GCM backup encryption keys.
- Keep MySQL and Redis inaccessible from the public internet.
- Expose only the frontend application entry point.
- Use HTTPS through a properly configured edge proxy or load balancer.
- Maintain persistent database storage.
- Maintain regular database backups.
- Validate application health after deployment.

GitHub OIDC integration is a planned security improvement for automated AWS authentication.

For production deployments, use AWS Secrets Manager or another suitable secrets-management solution instead of relying indefinitely on manually maintained environment files.

---

# 23. Technology Stack

| Category | Technology |
|---|---|
| Frontend | React |
| Frontend Build Tool | Vite |
| Frontend Web Server | Nginx |
| Backend | Spring Boot |
| Backend Language | Java 21 |
| Chatbot | Django + DRF |
| Chatbot Language | Python 3.11 |
| Database | MySQL 8.4 |
| Cache | Redis 7 |
| Containerization | Docker |
| Container Orchestration | Docker Compose |
| Container Registry | AWS ECR |
| Cloud Hosting | AWS EC2 |
| CI | GitHub Actions |
| Future AWS Authentication | GitHub OIDC |

---

# 24. Summary

The OneCare Infrastructure repository provides a centralized solution for local development and AWS deployment.

It supports two deployment workflows.

## Local Development

```text
Application Repositories
          |
          v
     Docker Compose
          |
          v
    Local Docker Builds
          |
          v
   Complete Application
```

Start the local environment using:

```bash
cd onecare-infra

docker compose up --build
```

## Current AWS EC2 Deployment

```text
Frontend Repository
Backend Repository
Chatbot Repository
          |
          v
   Manual Docker Builds
          |
          v
   Manual ECR Publishing
          |
          v
       AWS ECR
          |
          v
      AWS EC2
          |
    Manual Deployment
          |
          v
     Docker Compose
          |
    +-----+-----+
    |     |     |
    v     v     v
 Frontend Backend Chatbot
          |
      +---+---+
      |       |
      v       v
    MySQL   Redis
```

## Future Automated Deployment

```text
Application Repositories
          |
          v
     GitHub Actions
          |
          v
    Automated CI/CD
          |
          v
     AWS OIDC
          |
          v
        AWS ECR
          |
          v
       AWS EC2
          |
          v
     Docker Compose
```

GitHub OIDC and automated EC2 deployment are planned improvements and are not currently implemented.

The main responsibility of `onecare-infra` is to manage the complete application infrastructure, maintain the Docker Compose configurations and coordinate the deployment of the frontend, backend and chatbot images from AWS ECR to the EC2 instance.

This architecture allows OneCare to deploy and test the application using the current manual process while providing a clear path towards automated CI/CD in the future.

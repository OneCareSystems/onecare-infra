
# OneCare Infrastructure

Infrastructure and local development environment for the **OneCare Clinic Management System**.

This repository provides a Docker Compose environment that runs the complete OneCare application stack:

* React Frontend
* Spring Boot Backend
* MySQL Database
* Redis Cache
* Django Chatbot

The goal is to allow developers to start the complete local environment without manually installing or configuring MySQL, Redis, or the backend/frontend runtime environments.

---

## Architecture

The infrastructure consists of five services:

```text
                         OneCare Local Environment
                                  │
                         Docker Compose
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
          Frontend             Backend              MySQL
          React/Vite         Spring Boot              │
          Port 3000          Port 8080                │
              │                   │                   │
              └──────────────┬────┴───────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
            Redis                       Chatbot
          Port 6379                     Django
                                     Port 8000
```

### Services

| Service  | Technology            |   Port | Purpose                     |
| -------- | --------------------- | -----: | --------------------------- |
| Frontend | React + Vite          | `3000` | User interface              |
| Backend  | Spring Boot + Java 21 | `8080` | REST API and business logic |
| Database | MySQL 8.4             | `3306` | Persistent application data |
| Cache    | Redis 7               | `6379` | Caching and temporary data  |
| Chatbot  | Django 5 + DRF        | `8000` | AI chat service             |

---

## Repository Structure

The OneCare project uses separate repositories for the frontend, backend, chatbot, and infrastructure.

The repositories should be cloned into the same parent directory:

```text
OneCare/
├── onecare-backend/
│   ├── Dockerfile
│   ├── pom.xml
│   └── src/
├── onecare-chatbot/
│   ├── Dockerfile
│   ├── manage.py
│   ├── requirements.txt
│   └── onecare_chat/
│
├── onecare-frontend/
│   ├── Dockerfile
│   ├── package.json
│   └── src/
│
└── onecare-infra/
    ├── docker-compose.yml
    ├── .env.example
    ├── .gitignore
    └── README.md
```

The Docker Compose file uses the backend, chatbot, and frontend repositories as local Docker build contexts.

---

# Prerequisites

Install the following software before starting:

* Git
* Docker Desktop
* Docker Compose

Docker Compose is included with current versions of Docker Desktop.

Verify the installation:

```bash
docker --version
```

```bash
docker compose version
```

---

# Getting Started

## 1. Clone the repositories

Clone the four repositories into the same parent directory.

Example:

```bash
git clone https://github.com/OneCareSystems/onecare-backend
git clone https://github.com/OneCareSystems/onecare-chatbot
git clone https://github.com/OneCareSystems/onecare-frontend
git clone https://github.com/OneCareSystems/onecare-infra
```

The resulting structure should be:

```text
OneCare/
├── onecare-backend/
├── onecare-chatbot/
├── onecare-frontend/
└── onecare-infra/
```

> **Important:** Do not place the repositories inside each other. The repositories must be sibling directories.

---

## 2. Navigate to the infrastructure repository

```bash
cd onecare-infra
```

---

## 3. Create the environment file

Copy the example environment file:

### Windows PowerShell

```powershell
Copy-Item .env.example .env
```

### Linux / macOS

```bash
cp .env.example .env
```

Open `.env` and update the required values.

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
# dedicated chatbot database; must match 01_schemas_and_users.sql (dev/CI only)
CHATBOT_DB_PASSWORD=chatbot_dev_pw
# Spring Boot -> Django token, at least 32 characters
CHATBOT_SERVICE_TOKEN=<python -c "import secrets;print(secrets.token_urlsafe(48))">

REDIS_HOST=cache
REDIS_PORT=6379

JWT_SECRET=change_this_to_a_secure_secret
JWT_ACCESS_TOKEN_EXPIRY=1800000
JWT_REFRESH_TOKEN_EXPIRY=604800000
```

### Security

Do **not** commit `.env` to Git.

The `.gitignore` file should contain:

```gitignore
.env
```

Only `.env.example` should be committed.

---

# Start the Complete Environment

From the `onecare-infra` directory:

```bash
docker compose up --build
```

This command will:

1. Build the backend Docker image.
2. Build the chatbot Docker image.
3. Build the frontend Docker image.
4. Pull the MySQL image if it is not available locally.
5. Pull the Redis image if it is not available locally.
6. Create the Docker network.
7. Create the MySQL persistent volume.
8. Start MySQL.
9. Wait for MySQL to become healthy.
10. Start Redis.
11. Start the Spring Boot backend.
12. Start the Django chatbot (waits for MySQL to be healthy, runs migrations, then starts gunicorn).
13. Start the React frontend.

You do **not** need to manually run:

```bash
mvn spring-boot:run
```

or:

```bash
npm run dev
```

or manually start MySQL/Redis.

Docker Compose manages the complete local environment.

---

# Run in Background

To start all services in detached mode:

```bash
docker compose up --build -d
```

You can then continue using the terminal.

---

# Check Running Services

Run:

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

The backend and infrastructure services should report healthy when their health checks pass.

---

# Access the Application

Once all services are running:

### Frontend

```text
http://localhost:3000
```

### Backend

```text
http://localhost:8080
```

<!-- ### Backend Health Check

```text
http://localhost:8080/actuator/health
``` -->

### MySQL

```text
localhost:3306
```

### Redis

```text
localhost:6379
```

### Chatbot

```text
http://localhost:8000
```

The chatbot publishes only on `127.0.0.1` (localhost). Health check:

```text
http://localhost:8000/api/chatbot/health/
```

The chatbot uses its **own** schema `onecare_chatbot` (user `chatbot_app`), never the main
`onecare` database. Both are created by
`../onecare-chatbot/docker/mysql/init/01_schemas_and_users.sql` on the **first** start of a
fresh MySQL volume. If you had already been running the stack before this file was mounted,
run once:

```bash
docker compose down -v
docker compose up --build
```

> MySQL and Redis are infrastructure services and are normally accessed by the backend rather than directly through a browser.

---

# Service Communication

Inside the Docker network, containers should communicate using **service names**, not `localhost`.

For example:

```text
Backend → MySQL

jdbc:mysql://db:3306/onecare
```

Backend → Redis:

```text
cache:6379
```

Backend → Chatbot:

```text
http://chatbot:8000
```

Do **not** use:

```text
localhost:3306
```

or:

```text
localhost:6379
```

from inside the backend container.

`localhost` inside a container refers to that same container.

Docker Compose provides DNS resolution using service names:

```text
db
cache
backend
chatbot
frontend
```

---

# Database Persistence

MySQL uses a named Docker volume:

```text
onecare-mysql-data
```

This means database data persists even when containers are removed.

For example:

```bash
docker compose down
```

followed by:

```bash
docker compose up
```

will not delete the MySQL data.

---

# Stop the Environment

To stop the running containers:

```bash
docker compose down
```

This stops and removes the containers and network while preserving the MySQL named volume.

---

# Remove Database Data

⚠️ **Warning:** This permanently removes the local MySQL data stored in the Docker volume.

```bash
docker compose down -v
```

Use this only when you intentionally want a fresh database.

---

# View Logs

View logs for all services:

```bash
docker compose logs
```

Follow logs:

```bash
docker compose logs -f
```

View backend logs only:

```bash
docker compose logs -f backend
```

View frontend logs:

```bash
docker compose logs -f frontend
```

View MySQL logs:

```bash
docker compose logs -f db
```

View Redis logs:

```bash
docker compose logs -f cache
```

View chatbot logs:

```bash
docker compose logs -f chatbot
```

---

# Rebuild a Service

If you modify the backend:

```bash
docker compose build backend
docker compose up backend
```

If you modify the frontend:

```bash
docker compose build frontend
docker compose up frontend
```

If you modify the chatbot:

```bash
docker compose build chatbot
docker compose up chatbot
```

To rebuild everything:

```bash
docker compose up --build
```

---

# Useful Docker Commands

### List containers

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

### Stop the environment

```bash
docker compose down
```

### Stop and remove volumes

```bash
docker compose down -v
```

---

# Troubleshooting

## Port already in use

If port `3000` or `8080` is already being used, update the corresponding value in `.env`.

For example:

```env
FRONTEND_PORT=3001
BACKEND_PORT=8081
```

The container ports remain unchanged.

---

## Backend cannot connect to MySQL

Check the service status:

```bash
docker compose ps
```

Then check MySQL logs:

```bash
docker compose logs db
```

The backend should use:

```text
db:3306
```

and not:

```text
localhost:3306
```

---

## Backend health check fails

Check the backend logs:

```bash
docker compose logs backend
```

Also verify that the Spring Boot Actuator health endpoint is available:

```text
/actuator/health
```

The backend Docker image must also contain the required health-check utility.

---

## Frontend cannot connect to backend

Check that the backend is running:

```bash
docker compose ps
```

Then check:

```text
http://localhost:8080
```

Also verify the frontend environment/API configuration.

Remember that browser requests are made from the user's machine, so the frontend normally accesses the backend through the exposed host port:

```text
http://localhost:8080
```

rather than:

```text
http://backend:8080
```

`backend` is a Docker-network hostname and is primarily useful for container-to-container communication.

---

# Development Workflow

A typical development workflow is:

```text
1. Pull latest code
       ↓
2. Update backend/frontend repositories
       ↓
3. Update .env if necessary
       ↓
4. docker compose up --build
       ↓
5. Develop and test
       ↓
6. docker compose logs -f
       ↓
7. docker compose down
```

For example:

```bash
cd onecare-backend
git pull

cd ../onecare-frontend
git pull

cd ../onecare-infra
git pull

docker compose up --build
```

---

# Environment Variables

The following variables are configured through `.env`:

| Variable                   | Description                   |
| -------------------------- | ----------------------------- |
| `DB_HOST`                  | MySQL Docker service hostname |
| `DB_PORT`                  | MySQL host port               |
| `DB_NAME`                  | Database name                 |
| `DB_USER`                  | Application database user     |
| `DB_PASSWORD`              | Application database password |
| `DB_ROOT_PASSWORD`         | MySQL root password           |
| `BACKEND_PORT`             | Backend host port             |
| `FRONTEND_PORT`            | Frontend host port (also the CORS origin allowed by the backend) |
| `CHATBOT_PORT`             | Chatbot host port             |
| `CHATBOT_DB_PASSWORD`      | Password of the dedicated `chatbot_app` database user |
| `CHATBOT_SERVICE_TOKEN`    | Spring Boot → Django service token (min. 32 characters) |
| `DJANGO_SECRET_KEY`        | Optional Django secret key (local development only) |
| `REDIS_HOST`               | Redis Docker service hostname |
| `REDIS_PORT`               | Redis host port               |
| `JWT_SECRET`               | JWT signing secret            |
| `JWT_ACCESS_TOKEN_EXPIRY`  | Access token expiration       |
| `JWT_REFRESH_TOKEN_EXPIRY` | Refresh token expiration      |

Derived inside `docker-compose.yml` (no separate variable needed):

| Compose sets                              | Value                                             |
| ----------------------------------------- | ------------------------------------------------- |
| `FRONTEND_ALLOWED_ORIGINS` (backend)      | `http://localhost:FRONTEND_PORT`, `http://127.0.0.1:FRONTEND_PORT` |
| `PASSWORD_RESET_FRONTEND_BASE_URL`        | `http://localhost:FRONTEND_PORT`                  |
| `CHATBOT_URL` (backend)                   | `http://chatbot:8000/chat` (compose network)      |
| `VITE_API_BASE_URL` (frontend)            | `http://localhost:BACKEND_PORT/api`               |
| `DB_NAME` / `DB_USER` (chatbot)           | `onecare_chatbot` / `chatbot_app` (fixed by the chatbot repo) |

---

# Security Notes

* Never commit `.env`.
* Never commit production secrets.
* Use `.env.example` to document required variables.
* Use strong values for `JWT_SECRET`.
* Local development credentials must not be reused in production.
* Production deployment should use a proper secrets-management solution.

---

# Current Infrastructure Model

The current Docker Compose configuration builds the frontend, backend, and chatbot from their local repositories:

```text
onecare-infra
      │
      ├── ../onecare-backend
      │          ↓
      │      Docker build
      │
      ├── ../onecare-chatbot
      │          ↓
      │      Docker build
      │
      └── ../onecare-frontend
                 ↓
             Docker build
```

MySQL and Redis are pulled from their respective public container images.

---

# Future Container Registry Model

In a future CI/CD implementation, backend and frontend images can be built automatically by GitHub Actions and pushed to a container registry such as GitHub Container Registry (GHCR).

The architecture could then become:

```text
Backend Repository
       ↓
GitHub Actions
       ↓
Backend Docker Image
       ↓
Container Registry
       ↓
       ┐
       │
       ↓
Infrastructure Docker Compose
       ↑
       │
       ┘
       ↓
Frontend Docker Image
       ↑
GitHub Actions
       ↑
Frontend Repository
```

The Compose configuration would then use:

```yaml
backend:
  image: <backend-registry-image>

frontend:
  image: <frontend-registry-image>
```

Instead of:

```yaml
backend:
  build:
    context: ../onecare-backend

frontend:
  build:
    context: ../onecare-frontend
```

This is **not required for the current local development setup** and can be introduced later as part of the CI/CD/container registry implementation.

---

# Technology Stack

* Docker
* Docker Compose
* React
* Vite
* Node.js 20
* Spring Boot
* Java 21
* Django
* Python 3.11
* MySQL 8.4
* Redis 7
* GitHub Actions
---

## Summary

The purpose of this repository is to provide a **single local environment for the complete OneCare application**.

After the repositories are cloned into the correct structure, developers can start the entire environment with:

```bash
cd onecare-infra
docker compose up --build
```

This starts:

```text
React Frontend
      +
Spring Boot Backend
      +
Django Chatbot
      +
MySQL Database
      +
Redis Cache
```

without requiring developers to manually start each service.

---

# Continuous Integration

CI runs on pushes and pull requests to `develop` / `main`. Two workflows are involved.

## This repository — `.github/workflows/ci.yml`

Job `compose-validation`:

1. Validates `docker-compose.yml` against `.env.example`
   (`docker compose --env-file .env.example config --quiet`) — this is the clean-checkout
   state, where no `.env` exists yet, so a documented command must resolve before anything starts.
2. Fails if a secret is hard-coded in `docker-compose.yml` (values must come from `.env` via `${VAR}`).
3. Fails if any variable read by `docker-compose.yml` is missing from `.env.example`.

## Chatbot repository — `.github/workflows/ci.yml`

Job `chatbot` (the chat service, one job):

1. Checks out the chatbot repository and installs Python 3.11.9.
2. Validates dependency pins (`scripts/check_pins.py`).
3. Runs `ruff check .`.
4. Starts a MySQL 8 service container, waits until it accepts logins, then provisions the
   dedicated schema and restricted user (`db/create_chatbot_schema.ps1`) plus the CI stand-in schema.
5. Runs `python manage.py migrate`, asserts a **second migrate is a no-op** (AC3 idempotency),
   and `python manage.py makemigrations --check --dry-run`.
6. Runs the test suite `pytest -m "not embedding"` **against MySQL 8** (with coverage).
7. Runs `pip-audit` vulnerability scanning.
8. Builds the chatbot Docker image (`docker build -t onecare-chat .`).

Job `embedding-smoke` runs the embedding smoke test as a **separate** job (INFRA-02).

> The chatbot Docker image runs `scripts/entrypoint.sh`, which applies migrations and only then
> starts gunicorn; a migration failure exits non-zero and stops the container (AC3).


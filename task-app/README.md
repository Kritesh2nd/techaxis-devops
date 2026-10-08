# Task App

Node + Express + PostgreSQL CRUD app with a vanilla JS frontend and Jest/Supertest tests.

## Setup

```bash
docker compose up -d        # starts Postgres
npm install
npm start                   # http://localhost:3000
npm test                    # API tests, no database needed
```

No Docker? Create a `taskapp` database in your local Postgres and edit `.env`.

## API

| Method | Path             | Description              |
|--------|------------------|--------------------------|
| POST   | /api/tasks       | Create (`title` required)|
| GET    | /api/tasks       | List                     |
| GET    | /api/tasks/:id   | Get one                  |
| PUT    | /api/tasks/:id   | Update title/description/done |
| DELETE | /api/tasks/:id   | Delete                   |

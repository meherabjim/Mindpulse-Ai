# MindPulse AI Production Environment

This document records configuration names and safe examples. Production secret values must be stored in the deployment platform's secret manager and must not be committed.

## Backend environment

Use `backend/.env.example` as the local template. The real `backend/.env` remains ignored by Git.

| Variable | Classification | Example |
|---|---|---|
| `ADMIN_BCRYPT_ROUNDS` | Application configuration | `CHANGE_ME` |
| `ADMIN_JWT_ACCESS_EXPIRES_IN` | Application configuration | `CHANGE_ME` |
| `ADMIN_JWT_ACCESS_SECRET` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `ADMIN_JWT_AUDIENCE` | Application configuration | `CHANGE_ME` |
| `ADMIN_JWT_ISSUER` | Application configuration | `CHANGE_ME` |
| `ADMIN_REFRESH_TOKEN_DAYS` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `AI_SERVICE_API_KEY` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `AI_SERVICE_TIMEOUT_MS` | Application configuration | `CHANGE_ME` |
| `AI_SERVICE_URL` | Service endpoint | `https://service.example.com` |
| `BCRYPT_ROUNDS` | Application configuration | `CHANGE_ME` |
| `CORS_ALLOWED_ORIGINS` | Runtime | `https://app.example.com,https://admin.example.com` |
| `CORS_ALLOW_CREDENTIALS` | Runtime | `false` |
| `CORS_ORIGIN` | Service endpoint | `https://service.example.com` |
| `DB_HOST` | Database | `db.example.internal` |
| `DB_NAME` | Database | `mindpulse` |
| `DB_PASSWORD` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `DB_PORT` | Database | `3306` |
| `DB_USER` | Database | `mindpulse_app` |
| `FCM_ANDROID_CHANNEL_ID` | Application configuration | `CHANGE_ME` |
| `FCM_DRY_RUN` | Application configuration | `CHANGE_ME` |
| `FCM_MODE` | Application configuration | `CHANGE_ME` |
| `FIREBASE_PROJECT_ID` | Application configuration | `https://service.example.com` |
| `GOOGLE_APPLICATION_CREDENTIALS` | Application configuration | `CHANGE_ME` |
| `HOST` | Runtime | `0.0.0.0` |
| `JWT_ACCESS_EXPIRES_IN` | Application configuration | `CHANGE_ME` |
| `JWT_ACCESS_SECRET` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `JWT_AUDIENCE` | Application configuration | `CHANGE_ME` |
| `JWT_ISSUER` | Application configuration | `CHANGE_ME` |
| `NODE_ENV` | Runtime | `production` |
| `PORT` | Runtime | `5000` |
| `REFRESH_TOKEN_DAYS` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `REPORT_FILE_EXPIRY_DAYS` | Application configuration | `CHANGE_ME` |
| `REPORT_STORAGE_DIR` | Application configuration | `CHANGE_ME` |
| `RESET_ADMIN_EMAIL` | Operational maintenance | `CHANGE_ME` |
| `RESET_ADMIN_PASSWORD` | Operational maintenance | `CHANGE_ME_WITH_SECURE_VALUE` |
| `SUPER_ADMIN_EMAIL` | Operational maintenance | `CHANGE_ME` |
| `SUPER_ADMIN_NAME` | Operational maintenance | `CHANGE_ME` |
| `SUPER_ADMIN_PASSWORD` | Operational maintenance | `CHANGE_ME_WITH_SECURE_VALUE` |

## CORS production policy

`CORS_ALLOWED_ORIGINS` is a comma-separated origin allowlist.
Wildcard origins are rejected. Production startup fails when the allowlist is empty.
Requests without an `Origin` header remain available for mobile apps, health checks and server-to-server requests.

```env
CORS_ALLOWED_ORIGINS=https://app.example.com,https://admin.example.com
CORS_ALLOW_CREDENTIALS=false
```

## AI service environment

Use `ai_service/.env.example` as the local template. Database credentials must be provided through protected runtime variables.

| Variable | Classification | Example |
|---|---|---|
| `ALLOWED_ORIGINS` | Service endpoint | `https://service.example.com` |
| `APP_NAME` | Application configuration | `CHANGE_ME` |
| `DB_HOST` | Database | `db.example.internal` |
| `DB_NAME` | Database | `mindpulse` |
| `DB_PASSWORD` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `DB_PORT` | Database | `3306` |
| `DB_USER` | Database | `mindpulse_app` |
| `ENVIRONMENT` | Application configuration | `CHANGE_ME` |
| `HOST` | Runtime | `0.0.0.0` |
| `INTERNAL_API_KEY` | Sensitive | `CHANGE_ME_WITH_SECURE_VALUE` |
| `PORT` | Runtime | `5000` |

## Operational admin variables

`SUPER_ADMIN_*` and `RESET_ADMIN_*` variables are operational/bootstrap inputs. Do not expose them to clients or store them in application source.

## ML dependency pins

- `numpy==2.5.1`
- `pandas==3.0.3`
- `scikit-learn==1.9.0`
- `joblib==1.5.3`

## Secret handling

- Do not commit `.env` files, database passwords, JWT secrets or private keys.
- Use separate development and production credentials.
- Rotate credentials that appear in logs, tickets or chat messages.
- Use least-privilege database and deployment identities.

## Release gate

Run Backend ESLint/tests, AI dependency checks/tests, Flutter analysis/tests and GitHub Actions CI before deployment.

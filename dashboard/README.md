# DhanPath AI Dashboard (Mongo Rewrite)

Fresh Next.js dashboard with a basic SaaS workflow:
- Email/password signup and login (JWT + HTTP-only cookie)
- Family create/join using invite code
- Manual transactions stored per family
- Family summary (member spend, top categories, recent transactions)

## Stack

- Next.js App Router (TypeScript)
- MongoDB + Mongoose
- `bcryptjs` for password hashing
- `jsonwebtoken` for stateless auth

## Environment

Create `.env.local` from `.env.example`:

```bash
cp .env.example .env.local
```

Required values:

```env
MONGODB_URI=mongodb://127.0.0.1:27017
MONGODB_DB=dhanpath
JWT_SECRET=change_this_to_a_long_random_string
```

## Run

```bash
npm install
npm run dev
```

Open `http://localhost:3000`.

## Workflow

1. Go to `/auth` and sign up or login.
2. Create a family or join with invite code.
3. Add manual transactions.
4. See live family summary on `/family`.

## API Endpoints

- `POST /api/auth/signup`
- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `POST /api/family/create`
- `POST /api/family/join`
- `GET /api/family/summary`
- `GET /api/transactions`
- `POST /api/transactions`

## Validation

```bash
npm run lint
npm run build
```

Both commands pass on this rewrite.

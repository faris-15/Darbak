# Darbak — MinIO (S3) setup for your machine

Share this file with anyone who clones the project. **S3-compatible storage is already wired in the code** (`backend/utils/s3Config.js`, uploads on auth/shipment routes). They only need **Docker**, **environment variables**, and to **start MinIO** once.

---

## Prerequisites

| Tool | Why |
|------|-----|
| **Git** | Clone the repo |
| **Docker Desktop** (Windows/Mac) or **Docker Engine** (Linux) | Runs MinIO + one-off init container |
| **Node.js** (LTS) | Runs the backend API |

Optional: **Flutter** if they also run the mobile app.

---

## Step 1 — Clone and install the backend

```bash
git clone <YOUR_REPO_URL> Darbak1
cd Darbak1/backend
npm install
```

---

## Step 2 — Create `backend/.env`

1. Copy the example file:

   ```bash
   cd Darbak1/backend
   copy .env.example .env
   ```

   (On Mac/Linux: `cp .env.example .env`)

2. Open **`backend/.env`** in an editor. **Do not commit `.env`** to git (it is usually ignored).

3. Keep MySQL/JWT keys as your team agrees; for MinIO, set at least the block below (values must match **`docker-compose.yml`** unless you change both places together).

---

## Step 3 — Start MinIO (Docker)

From the **project root** (folder that contains `docker-compose.yml`), not inside `backend/`:

**Windows CMD:**

```cmd
cd /d C:\path\to\Darbak1
docker compose up -d minio
docker compose run --rm minio_init
docker compose ps
```

**PowerShell / Mac / Linux:**

```bash
cd /path/to/Darbak1
docker compose up -d minio
docker compose run --rm minio_init
docker compose ps
```

**What this does**

- **`minio`** — S3-compatible server. **API** is published on host port **9190**, **web console** on **9191**.
- **`minio_init`** (runs once) — creates buckets **`darbak`** and **`darbak-uploads`**, applies **CORS** from `docker/minio-cors.json`.

**Optional — open the MinIO web UI**

- URL: `http://127.0.0.1:9191`
- Login: same as in `docker-compose.yml` → default **`admin`** / **`password123`** (change for real deployments).

---

## Step 4 — Configure S3 variables in `backend/.env`

| Variable | What to put | Typical mistake |
|----------|-------------|-----------------|
| **`MINIO_ENDPOINT`** | Host + **API port only**: `127.0.0.1:9190` or `localhost:9190` (no `http://` is OK; the code adds it). | Using **9191** (console) → error *“S3 API Requests must be made to API port”*. |
| **`MINIO_ACCESS_KEY`** | Same as **`MINIO_ROOT_USER`** in `docker-compose.yml` (default `admin`). | Typos vs Docker env. |
| **`MINIO_SECRET_KEY`** | Same as **`MINIO_ROOT_PASSWORD`** in `docker-compose.yml` (default `password123`). | Same. |
| **`MINIO_BUCKET`** | `darbak-uploads` or `darbak` (both are created by `minio_init`). | Bucket name typo → access errors. |
| **`MINIO_EXTERNAL_URL`** | Full URL including **`http://`** for **signing download links**. Must use **API port 9190**, not 9191. | Using console port; or `localhost` when phones need LAN IP (see below). |

**Examples**

- **Backend and Docker on the same PC only** (emulator on same machine testing presigned URLs):

  ```env
  MINIO_ENDPOINT=127.0.0.1:9190
  MINIO_EXTERNAL_URL=http://127.0.0.1:9190
  MINIO_BUCKET=darbak-uploads
  ```

- **Physical phone on Wi‑Fi** must open presigned URLs on your PC’s **LAN IP** (find with `ipconfig` on Windows):

  ```env
  MINIO_ENDPOINT=127.0.0.1:9190
  MINIO_EXTERNAL_URL=http://192.168.x.x:9190
  MINIO_BUCKET=darbak-uploads
  ```

  Replace `192.168.x.x` with your PC’s IPv4. **Firewall** may need to allow inbound **9190**.

---

## Step 5 — Run the API and confirm S3

```bash
cd Darbak1/backend
npm start
```

In the terminal you want:

- **`[S3] HeadBucket OK — API reachable.`** → MinIO + bucket + `.env` are correct.

If you see warnings, use **Section 8 — Troubleshooting**.

---

## Step 6 — Flutter / mobile (short)

- The app talks to the **backend** (e.g. `10.0.2.2:5000` from Android emulator to host — see `lib/api_service.dart`).
- **File download URLs** often come from the backend as **presigned MinIO URLs**. Those URLs use **`MINIO_EXTERNAL_URL`**, so that host must be reachable from the **phone/emulator** (LAN IP + port **9190**).

---

## 7 — Port cheat sheet (send this table)

| Host port | Use |
|-----------|-----|
| **9190** | **S3 API** — `MINIO_ENDPOINT`, `MINIO_EXTERNAL_URL`, uploads, presigned GET |
| **9191** | **Browser admin UI only** — never put this in `MINIO_ENDPOINT` |

---

## 8 — Troubleshooting

| Symptom | Likely cause | Fix |
|--------|----------------|-----|
| `Invalid hostname` when running `minio_init` | Old compose used a bad internal name. | Pull latest `docker-compose.yml`; service must be **`minio`**, URL **`http://minio:9000`** inside init. |
| `S3 API Requests must be made to API port` | Console port in `.env`. | Use **9190** for API, not **9191**. |
| `char 'N' is not expected` / XML parse error, body **Not Found**, **404** | Something else (e.g. Apache) on that port, or wrong port. | Ensure Docker maps **9190→9000**; free the port; restart `minio`. |
| HeadBucket OK but phone cannot open file URL | `MINIO_EXTERNAL_URL` uses `localhost`. | Use PC **LAN IP** and open firewall for **9190**. |
| CORS errors in browser | Strict origins. | Dev uses `docker/minio-cors.json` with `*`. Tighten for production. |

---

## 9 — Optional: use real AWS S3 instead of MinIO

Advanced: unset **`MINIO_ENDPOINT`**, set AWS credentials and region per AWS SDK docs, and align bucket/region with your account. The project is primarily tested with **MinIO path-style**; AWS may need extra tuning.

---

## 10 — Files reference (for developers)

| Path | Role |
|------|------|
| `docker-compose.yml` | `minio` + `minio_init` |
| `docker/minio-cors.json` | CORS applied to both buckets |
| `backend/.env.example` | Template for all env vars |
| `backend/utils/s3Config.js` | S3 client, uploads, presigned URLs |
| `backend/routes/authRoutes.js` | Registration document → S3 |
| `backend/routes/shipmentRoutes.js` | EPOD photo → S3 |

---

**Security note:** Default MinIO credentials in `docker-compose.yml` are for **local development only**. Change them (and `.env`) before any shared or public deployment.

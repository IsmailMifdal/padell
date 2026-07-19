# Déploiement production (VPS)

Cible : un VPS Ubuntu (Hetzner/OVH/Contabo, 4-8 Go) avec Docker — cf. docs/02 §7.
Tout est prêt dans [deploy/](../deploy) : API conteneurisée, PostgreSQL+PostGIS,
Redis, Nginx avec HTTPS Let's Encrypt auto-renouvelé, **backups quotidiens**.

## 1. Prérequis
- Un domaine (ex : `api.mondomaine.ma`) avec un enregistrement **A** vers l'IP du VPS.
- Docker + plugin compose sur le VPS : `curl -fsSL https://get.docker.com | sh`

## 2. Installation
```bash
git clone https://github.com/IsmailMifdal/padell.git && cd padell/deploy
cp .env.example .env && nano .env          # secrets : POSTGRES_PASSWORD, JWT_SECRET…
sed -i 's/api.example.ma/api.mondomaine.ma/g' nginx/padel.conf
```

## 3. Premier certificat HTTPS
```bash
# Démarrer nginx seul (port 80) pour le challenge ACME
docker compose -f docker-compose.prod.yml up -d nginx
docker compose -f docker-compose.prod.yml run --rm certbot \
  certonly --webroot -w /var/www/certbot \
  -d api.mondomaine.ma --email vous@mondomaine.ma --agree-tos --no-eff-email
```

## 4. Lancement complet
```bash
docker compose -f docker-compose.prod.yml up -d --build
# L'API applique ses migrations Prisma automatiquement au démarrage.
curl https://api.mondomaine.ma/v1/health     # → {"status":"ok"}
# Documentation interactive : https://api.mondomaine.ma/docs
```

## 5. Premier administrateur
```bash
# Après inscription d'un compte via l'app :
docker compose -f docker-compose.prod.yml exec db \
  psql -U padel -d padel -c "UPDATE users SET roles='{PLAYER,ADMIN}' WHERE email='vous@mondomaine.ma';"
```

## 6. Backups & restauration
- Le service `backup` fait un `pg_dump -Fc` **quotidien** dans `deploy/backups/`
  (rétention 30 jours). Copier ce dossier hors du serveur (rclone → S3/R2 recommandé).
- **Restauration** (testée — voir aussi `deploy/scripts/`) :
```bash
docker compose -f docker-compose.prod.yml exec -T db \
  pg_restore -U padel -d padel --clean --if-exists < backups/padel-YYYYMMDD-HHMM.dump
```

## 7. Après le déploiement
- **App mobile** : rebuild avec `--dart-define=API_URL=https://api.mondomaine.ma/v1`.
- **Dashboard admin** : `NEXT_PUBLIC_API_URL=https://api.mondomaine.ma/v1` (déployable sur Vercel).
- **UptimeRobot** : monitor HTTP sur `https://api.mondomaine.ma/v1/health` (mot-clé `ok`).
- **CMI** : déclarer `CMI_CALLBACK_URL` auprès de la banque.
- Mises à jour : `git pull && docker compose -f docker-compose.prod.yml up -d --build`.

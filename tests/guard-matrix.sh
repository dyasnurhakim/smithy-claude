#!/usr/bin/env bash
set -u
# Self-contained guard.sh test matrix. Run: bash tests/guard-matrix.sh
G="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/guard.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
cd "$SCRATCH" && git init -q -b main && mkdir -p docs/smithy
bash $G revoke >/dev/null
fails=0
t() { if bash $G check "$2" >/dev/null 2>&1; then got=ALLOW; else got=BLOCK; fi
  if [ "$got" = "$1" ]; then printf 'PASS  %-5s %s\n' "$got" "$2"; else printf 'FAIL! want=%s got=%s  %s\n' "$1" "$got" "$2"; fails=$((fails+1)); fi; }

echo "--- cloud ---"
t BLOCK "aws ec2 terminate-instances --instance-ids i-12345"
t BLOCK "aws s3 rb s3://prod-bucket --force"
t BLOCK "aws s3 rm s3://bucket/data --recursive"
t BLOCK "aws rds delete-db-instance --db-instance-identifier prod"
t BLOCK "gcloud compute instances delete my-vm --zone us-east1-b"
t BLOCK "gsutil rm -r gs://bucket"
t BLOCK "az vm delete -g rg -n vm1 --yes"
t BLOCK "terraform destroy -auto-approve"
t BLOCK "pulumi destroy --yes"
t BLOCK "heroku pg:reset DATABASE_URL"
t ALLOW "aws s3 ls s3://bucket"
t ALLOW "aws ec2 describe-instances"
t ALLOW "terraform plan"
echo "--- containers ---"
t BLOCK "docker rm -f my-container"
t BLOCK "docker rmi node:20"
t BLOCK "docker system prune -af"
t BLOCK "docker volume rm pgdata"
t BLOCK "docker compose down -v"
t BLOCK "docker-compose down"
t BLOCK "kubectl delete pod web-7d9f"
t BLOCK "kubectl drain node-1"
t BLOCK "helm uninstall my-release"
t ALLOW "docker ps -a"
t ALLOW "docker compose up -d"
t ALLOW "kubectl get pods"
t ALLOW "docker build -t app ."
echo "--- databases ---"
t BLOCK "psql -c 'DROP TABLE users;'"
t BLOCK "mysql -e 'drop database prod'"
t BLOCK "psql -c 'TRUNCATE orders'"
t BLOCK "sqlite3 app.db 'DELETE FROM logs'"
t ALLOW "psql -c 'DELETE FROM logs WHERE created_at < now()'"
t BLOCK "redis-cli flushall"
t BLOCK "mongosh --eval 'db.dropDatabase()'"
t BLOCK "dropdb production"
t BLOCK "mysqladmin drop mydb"
t BLOCK "npx prisma migrate reset --force"
t BLOCK "rails db:drop"
t BLOCK "php artisan migrate:fresh"
t BLOCK "python manage.py flush --noinput"
t ALLOW "psql -c 'SELECT * FROM users LIMIT 5'"
t ALLOW "npx prisma migrate dev"
echo "--- filesystem ---"
t BLOCK "find . -name '*.log' -delete"
t BLOCK "rsync -av --delete src/ dest/"
t BLOCK "shred -u secrets.txt"
t BLOCK "dd if=/dev/zero of=/dev/sda"
t BLOCK "truncate -s 0 app.log"
t ALLOW "find . -name '*.log' -type f"
t ALLOW "rsync -av src/ dest/"
echo "--- allow-once escape hatch ---"
t BLOCK "docker rm old-container"
bash $G allow-once >/dev/null
t ALLOW "docker rm old-container"
t BLOCK "docker rm old-container"
echo "--- allow-once does NOT unlock push ---"
bash $G allow-once >/dev/null
t BLOCK "git push origin main"
bash $G revoke >/dev/null
echo "--- git regression ---"
t BLOCK "git push --force"
t BLOCK "git reset --hard HEAD~1"
t BLOCK "git commit -m x"
bash $G grant demo >/dev/null
t ALLOW "git commit -m x"
t ALLOW "git commit -m 'fix: drop table bug in parser'"
bash $G revoke >/dev/null
echo "--- non-smithy dir stands down ---"
cd /tmp
t ALLOW "terraform destroy"
echo "=== FAILURES: $fails ==="
exit $fails

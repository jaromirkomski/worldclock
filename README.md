# World Clock

Aplikacja webowa REST API zwracająca aktualny czas w 8 miastach na świecie.

## Architektura

```
GitHub → GitHub Actions → Amazon ECR → Amazon ECS (Fargate) → ALB → Cloudflare DNS → Public URL
```

- **GitHub** — repozytorium kodu
- **GitHub Actions** — pipeline CI/CD (testy, build, deploy)
- **Amazon ECR** — rejestr obrazów Docker
- **Amazon ECS Fargate** — uruchomienie kontenera bez zarządzania serwerami
- **ALB** — Application Load Balancer, health check, stabilny DNS
- **Cloudflare DNS** — własna domena
- **Terraform** — infrastruktura jako kod (VPC, subnety, ALB, ECS, ECR, IAM, CloudWatch)

## Endpointy

| Endpoint | Opis |
|----------|------|
| `GET /health` | Status aplikacji |
| `GET /version` | Wersja aplikacji |
| `GET /api/time?city=Warsaw` | Czas w podanym mieście |

Dostępne miasta: `Warsaw`, `London`, `New York`, `Los Angeles`, `Moscow`, `Tokyo`, `Beijing`, `Sydney`

## Uruchomienie lokalne

```bash
# bez Dockera
npm install
npm start

# z Dockerem
docker build -t worldclock .
docker run -p 3000:3000 worldclock
```

## Testy

```bash
npm test
```

## Infrastruktura (Terraform)

```bash
cd terraform
terraform init
terraform apply
```

## CI/CD

Pipeline uruchamia się automatycznie przy każdym pushu do `main`:

1. Uruchomienie testów (`npm test`)
2. Budowanie obrazu Docker
3. Publikowanie obrazu w Amazon ECR
4. Wdrożenie na Amazon ECS

## Link do aplikacji

http://worldclock.fantastycznydompanajaromira.uk

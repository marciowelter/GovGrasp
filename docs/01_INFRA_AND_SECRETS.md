# Infrastructure as Code (IaC) and Secrets Management

This document describes how the infrastructure for **GovGrasp** is provisioned and how sensitive data (passwords, API keys, tokens) is handled, following DevSecOps best practices.

---

## 0. Developer Quick-Start (local environment)

This section is what a **new developer** needs to read first.

### Step 1 — Clone and bootstrap

```bash
git clone https://github.com/your-org/GovGrasp.git
cd GovGrasp
bash scripts/setup.sh     # installs Docker, Terraform, AWS CLI, Python tools
```

> If you get `permission denied` on the Docker socket after `setup.sh`, run `newgrp docker` to apply the new group without logging out.

### Step 2 — Configure environment variables

```bash
cp .env.example .env
nano .env
```

Fill in **at minimum** these two values:

| Variable | Where to get it |
|---|---|
| `DB_PASSWORD` | Any string for local dev (e.g. `secret`) |
| `OPEN_CLAW_API_KEY` | Request from the team admin |

Leave `APP_KEY` blank — it is generated automatically in Step 4.
Leave all `AWS_*` variables blank — they are only needed for cloud deployment.

### Step 3 — Start local services

```bash
docker compose up -d
docker compose ps        # db=Up, backend=Up, worker=Up
```

### Step 4 — Generate the Laravel application key (first run only)

```bash
docker exec govgrasp_backend php artisan key:generate
```

To persist the key across Docker rebuilds, copy it to your host `.env`:

```bash
docker exec govgrasp_backend grep APP_KEY /var/www/html/.env >> .env
```

### Step 5 — Run database migrations

```bash
docker exec govgrasp_backend php artisan migrate
```

### Verify everything works

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000
# Expected output: 200
```

---

## 1. Infrastructure Tool: Terraform

We use **Terraform** (HashiCorp) to provision AWS resources.
Infrastructure is treated as an independent microservice from the application code, ensuring the environment can be fully recreated (Disaster Recovery) with a single command (`terraform apply`).

---

## 2. Secrets Management (AWS Secrets Manager)

**Golden Rule:** No credentials (database passwords, API tokens, LLM keys) will be hardcoded in the source code or pushed to GitHub.

### How the secrets architecture works

1. **The Vault:** Terraform provisions a logical container in AWS Secrets Manager named `govgrasp/production/app-secrets`.
2. **State Separation:** Terraform code **never** contains secret values to prevent leakage via `terraform.tfstate`.
3. **Serverless Injection:** ECS Fargate tasks have a read-only IAM Role (least privilege). When a Laravel or Python container starts, AWS fetches the secret from Secrets Manager and injects it as an environment variable — no secrets in Docker images or compose files.

### Local vs production secrets

| Where | Mechanism | File |
|---|---|---|
| Local development | `.env` file (gitignored) | `.env` (copy from `.env.example`) |
| CI/CD | GitHub Actions secrets | Repository Settings → Secrets |
| Production (AWS) | Secrets Manager → ECS env injection | `govgrasp/production/app-secrets` |

### Values stored in Secrets Manager (production)

| Key | Purpose |
|---|---|
| `DB_HOST` | Amazon RDS endpoint |
| `DB_USER` | RDS database user |
| `DB_PASSWORD` | RDS database password |
| `OPEN_CLAW_API_KEY` | AI orchestration API key |
| `LLM_PROVIDER_TOKEN` | OpenAI / Anthropic / Google token |
| `GITHUB_TOKEN` | CI/CD pipeline integrations |

---

## 3. Environment Variable Reference

All variables are documented in [`.env.example`](../.env.example). The table below explains each one:

| Variable | Required locally | Description |
|---|---|---|
| `DB_DATABASE` | Yes | PostgreSQL database name |
| `DB_USER` | Yes | PostgreSQL user |
| `DB_PASSWORD` | Yes | PostgreSQL password |
| `APP_KEY` | Auto-generated | Laravel encryption key (`php artisan key:generate`) |
| `APP_ENV` | Yes | `local` for development, `production` for AWS |
| `APP_DEBUG` | Yes | `true` locally, **`false` in production** |
| `APP_URL` | Yes | Base URL (`http://localhost:8000` locally) |
| `OPEN_CLAW_API_KEY` | Yes | API key for the AI worker |
| `AWS_ACCESS_KEY_ID` | No (local) | AWS credentials — only needed for deployment |
| `AWS_SECRET_ACCESS_KEY` | No (local) | AWS credentials — only needed for deployment |
| `AWS_DEFAULT_REGION` | No (local) | Default: `eu-west-2` (London) |

---

# Infrastructure as Code (IaC) e Gestão de Segredos — Versão PT-BR

Este documento descreve como a infraestrutura do **GovGrasp** é provisionada e como lidamos com dados sensíveis (senhas, chaves de API, tokens), seguindo as melhores práticas de DevSecOps.

---

## 0. Início Rápido para Desenvolvedores (ambiente local)

### Passo 1 — Clonar e instalar dependências

```bash
git clone https://github.com/your-org/GovGrasp.git
cd GovGrasp
bash scripts/setup.sh     # instala Docker, Terraform, AWS CLI, ferramentas Python
```

> Se aparecer `permission denied` no socket do Docker após o `setup.sh`, execute `newgrp docker` para aplicar o novo grupo sem precisar fazer logout.

### Passo 2 — Configurar variáveis de ambiente

```bash
cp .env.example .env
nano .env
```

Preencha **no mínimo** estas duas variáveis:

| Variável | Como obter |
|---|---|
| `DB_PASSWORD` | Qualquer string para dev local (ex: `secret`) |
| `OPEN_CLAW_API_KEY` | Solicite ao administrador do time |

Deixe `APP_KEY` em branco — ele é gerado automaticamente no Passo 4.
Deixe as variáveis `AWS_*` em branco — são necessárias apenas para deploy em nuvem.

### Passo 3 — Subir os serviços locais

```bash
docker compose up -d
docker compose ps        # db=Up, backend=Up, worker=Up
```

### Passo 4 — Gerar a chave da aplicação Laravel (apenas na primeira vez)

```bash
docker exec govgrasp_backend php artisan key:generate
```

Para persistir a chave entre rebuilds do Docker, copie para o `.env` do host:

```bash
docker exec govgrasp_backend grep APP_KEY /var/www/html/.env >> .env
```

### Passo 5 — Executar as migrações do banco de dados

```bash
docker exec govgrasp_backend php artisan migrate
```

### Verificar se tudo funciona

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8000
# Saída esperada: 200
```

---

## 1. Ferramenta de Infraestrutura: Terraform

Utilizamos o **Terraform** (HashiCorp) para provisionar recursos na AWS.
A infraestrutura é tratada como um microsserviço independente do código da aplicação, garantindo que o ambiente possa ser recriado (Disaster Recovery) com apenas um comando (`terraform apply`).

---

## 2. Gestão de Segredos (AWS Secrets Manager)

**Regra de Ouro:** Nenhuma credencial (senhas de banco, tokens de API, chaves do LLM) será hardcoded no código-fonte ou enviada para o GitHub.

### Como funciona a arquitetura de segredos

1. **O Cofre (Vault):** O Terraform provisiona um contêiner lógico no AWS Secrets Manager chamado `govgrasp/production/app-secrets`.
2. **Separação de Estado:** O código Terraform **nunca** contém os valores dos segredos para evitar vazamento no arquivo `terraform.tfstate`.
3. **Injeção Serverless:** As tasks do ECS Fargate possuem uma IAM Role de leitura (least privilege). Quando o container Laravel ou Python inicia, a própria AWS vai ao Secrets Manager e injeta o segredo como variável de ambiente — nenhum segredo fica em imagens Docker ou arquivos compose.

### Local vs produção

| Onde | Mecanismo | Arquivo |
|---|---|---|
| Desenvolvimento local | Arquivo `.env` (no .gitignore) | `.env` (copiado de `.env.example`) |
| CI/CD | GitHub Actions secrets | Repository Settings → Secrets |
| Produção (AWS) | Secrets Manager → injeção ECS | `govgrasp/production/app-secrets` |

### Valores armazenados no Secrets Manager (produção)

| Chave | Finalidade |
|---|---|
| `DB_HOST` | Endpoint do Amazon RDS |
| `DB_USER` | Usuário do banco de dados RDS |
| `DB_PASSWORD` | Senha do banco de dados RDS |
| `OPEN_CLAW_API_KEY` | Chave de API para orquestração da IA |
| `LLM_PROVIDER_TOKEN` | Token da OpenAI / Anthropic / Google |
| `GITHUB_TOKEN` | Integrações do pipeline de CI/CD |

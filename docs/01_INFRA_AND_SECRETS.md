# Infrastructure as Code (IaC) and Secrets Management

This document describes how the infrastructure for **GovGrasp** is provisioned and how we handle sensitive data (passwords, API keys, tokens), following DevSecOps best practices.

## 1. Chosen Tool: Terraform
We use **Terraform** (HashiCorp) to provision our resources on AWS.
Infrastructure is treated as an independent microservice from the application code, ensuring that the environment can be recreated (Disaster Recovery) with a single command (`terraform apply`).

## 2. Secrets Management (AWS Secrets Manager)
**Golden Rule:** No credentials (database passwords, API tokens, LLM keys) will be hardcoded in the source code or pushed to GitHub.

### How our secrets architecture works:
1. **The Vault:** Terraform provisions a logical container in AWS Secrets Manager called `govgrasp/production/app-secrets`.
2. **State Separation:** The Terraform code **never** contains the secret values to prevent leakage in the `terraform.tfstate` file.
3. **Serverless Injection:** AWS ECS (Fargate) has a read-only IAM Role ("Least Privilege"). When the Laravel or Python container starts, AWS itself fetches the password from Secrets Manager and injects it as an **Environment Variable**.

### 3. How to configure locally (Developers)
Since we do not have access to AWS Secrets Manager in our local machine environment, we use `.env` files.

1. Copy the example file: `cp .env.example .env`
2. Request the development tokens from the system administrator.
3. The `.env` file is explicitly ignored in our `.gitignore`. **Never commit the `.env` file.**

### 4. Values stored in Secrets Manager (Production)
Below are the keys the application expects to find in the production environment:
- `DB_HOST`, `DB_USER`, `DB_PASSWORD` (Amazon RDS Access)
- `OPEN_CLAW_API_KEY` (Key for AI orchestration)
- `LLM_PROVIDER_TOKEN` (OpenAI/Anthropic/Google token for text analysis)
- `GITHUB_TOKEN` (For CI/CD pipeline integrations)

---
---

# Infrastructure as Code (IaC) e Gestão de Segredos

Este documento descreve como a infraestrutura do **GovGrasp** é provisionada e como lidamos com dados sensíveis (senhas, chaves de API, tokens), seguindo as melhores práticas de DevSecOps.

## 1. Ferramenta Escolhida: Terraform
Utilizamos o **Terraform** (HashiCorp) para provisionar nossos recursos na AWS.
A infraestrutura é tratada como um microsserviço independente do código da aplicação, garantindo que o ambiente possa ser recriado (Disaster Recovery) com apenas um comando (`terraform apply`).

## 2. Gestão de Segredos (AWS Secrets Manager)
**Regra de Ouro:** Nenhuma credencial (senhas de banco, tokens de API, chaves do LLM) será hardcoded no código-fonte ou enviada para o GitHub.

### Como funciona a nossa arquitetura de segredos:
1. **O Cofre (Vault):** O Terraform provisiona um contêiner lógico no AWS Secrets Manager chamado `govgrasp/production/app-secrets`.
2. **Separação de Estado:** O código Terraform **nunca** contém os valores dos segredos para evitar vazamento no arquivo `terraform.tfstate`.
3. **Injeção Serverless:** O AWS ECS (Fargate) possui uma IAM Role (Permissão) de leitura ("Least Privilege"). Quando o container do Laravel ou do Python liga, a própria AWS vai até o Secrets Manager, busca a senha e a injeta como uma **Variável de Ambiente**.

### 3. Como configurar localmente (Desenvolvedores)
Como não temos acesso ao Secrets Manager da AWS no ambiente local da nossa máquina, utilizamos arquivos `.env`.

1. Copie o arquivo de exemplo: `cp .env.example .env`
2. Solicite os tokens de desenvolvimento ao administrador do sistema.
3. O arquivo `.env` está explicitamente ignorado no nosso `.gitignore`. **Nunca faça commit do `.env`.**

### 4. Valores armazenados no Secrets Manager (Produção)
Abaixo estão as chaves que a aplicação espera encontrar no ambiente de produção:
- `DB_HOST`, `DB_USER`, `DB_PASSWORD` (Acesso ao Amazon RDS)
- `OPEN_CLAW_API_KEY` (Chave para orquestração da IA)
- `LLM_PROVIDER_TOKEN` (Token da OpenAI/Anthropic/Google para análise de texto)
- `GITHUB_TOKEN` (Para integrações do pipeline de CI/CD)
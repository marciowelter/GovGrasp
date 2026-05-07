# Usa a imagem oficial slim do Python 3.11
FROM python:3.11-slim

# Impede o Python de gravar arquivos .pyc e de fazer buffer no log (melhor para CloudWatch)
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Define o diretório de trabalho
WORKDIR /app

# Instala dependências de sistema necessárias para psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

# Cria um usuário não-root por segurança
RUN addgroup --system worker && adduser --system --group worker

# Copia os requisitos primeiro (para aproveitar o cache do Docker)
COPY requirements.txt .

# Atualiza o pip e instala dependências
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copia o restante do código
COPY . .

# Ajusta permissões
RUN chown -R worker:worker /app

# Troca para o usuário seguro
USER worker

EXPOSE 8001

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8001"]

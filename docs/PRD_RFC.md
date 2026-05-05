# GovGrasp: Product Requirements Document (PRD) / RFC

## 1. Project Overview
Created exclusively for demonstration and educational purposes to showcase the potential of integrating different technologies. GovGrasp is an automated intelligence pipeline designed to monitor, filter, and analyze UK government procurement opportunities directly or potential partnership proposals with winning companies of relevant tenders. By leveraging AI Agents (Scout and Analyst) via the Open Claw framework, the system identifies high-value software and technology contracts, providing a competitive edge for B2B tech companies.

---

## 2. Goals & Objectives
- **Automated Discovery:** Eliminate manual searching by polling the UK Contracts Finder API every 12 hours.
- **Intelligent Filtering:** Use Artificial Intelligence from an LLM to distinguish between general services and specific "Software/Digital" opportunities.
- **Data-Driven Strategy:** Extract key metadata (values, frameworks like G-Cloud, deadlines) to inform sales decisions.

---

## 3. Scope (What the System WILL Do)
- **API Integration:** Connect to the UK Contracts Finder OCDS API.
- **Agentic Workflow:**
    - **Scout Agent:** Fetches and normalizes raw JSON data.
    - **Analyst Agent:** Filters opportunities based on tech-specific keywords and requirements, as well as potential partnerships with companies that have won tenders.
- **12-Hour Cycle:** Run automated batches twice a day to ensure data freshness.
- **Audit Logs:** Maintain logs of all fetched and analyzed opportunities for compliance and debugging.
- **Secure Infrastructure:** Deploy using AWS best practices (IAM least privilege, Secrets Manager) and utilizing AWS Serverless solutions.

---

## 4. Anti-Scope (What the System WILL NOT Do)
- **Automated Bidding:** The system will NOT submit bids or interact with government portals beyond data retrieval.
- **Non-Tech Tenders:** General construction, logistics, or non-digital service tenders will be discarded.
- **Legal Advice:** The AI analysis is for business intelligence only and does not constitute legal procurement advice.
- **User Authentication:** No login system for the data retrieval phase to maintain "Open Data" simplicity.

---

## 5. Data Flow
1. **Trigger:** CloudWatch Events / Cron triggers the workflow every 12 hours, or on-demand via the React administration interface.
2. **Ingestion:** Python `API Tool` requests data from UK Contracts Finder (OCDS).
3. **Processing (Scout):** Raw JSON is parsed; duplicates are removed.
4. **Analysis (Analyst):** The LLM evaluates the description/tags against criteria for tenders involving "Software Development".
5. **Output:** Qualified opportunities are stored (S3/Database) and notified to the user on the application interface and sent via email or WhatsApp.

---

## 6. Service Level Objectives (SLOs)
- **Data Freshness:** New tenders must be processed within 5 minutes of the 12-hour trigger.
- **Analysis Latency:** Total processing time per batch (max 100 notices) should be under 2 minutes.
- **Availability:** The polling service should have 99.5% uptime (excluding external API downtime).
- **Security:** 100% of API keys and internal tokens must be rotated via AWS Secrets Manager.

---

## 7. Consumers & Stakeholders
- **Sales Teams:** Primary users consuming the filtered lead reports.
- **Solution Architects:** Use the data to understand technical requirements in the market.
- **DevOps/SRE:** Responsible for maintaining the AWS pipeline and Open Claw orchestration.

---
# Brazilian Portuguese
---

# GovGrasp: Documento de Requisitos do Produto (PRD) / RFC

## 1. Visão Geral do Projeto
Criado exclusivamente para fins de demonstração e didáticos do potencial de tecnologias diferentes integradas. O GovGrasp é um pipeline de inteligência automatizado projetado para monitorar, filtrar e analisar oportunidades de compras do governo do Reino Unido diretamente ou possíveis propostas de parceria com empresas ganhadoras de licitações de interesse. Ao utilizar Agentes de IA (Scout e Analyst) através do framework Open Claw, o sistema identifica contratos de tecnologia e software de alto valor, proporcionando uma vantagem competitiva para empresas de tecnologia B2B.

## 2. Metas e Objetivos
- **Descoberta Automatizada:** Eliminar a busca manual consultando a API do UK Contracts Finder a cada 12 horas.
- **Filtragem Inteligente:** Usar Inteligência Artificial de um LLMs para distinguir entre serviços gerais e oportunidades específicas de "Software/Digital".
- **Estratégia Baseada em Dados:** Extrair metadados cruciais (valores, frameworks como G-Cloud, prazos) para informar decisões de vendas.

## 3. Escopo (O que o sistema FARÁ)
- **Integração de API:** Conectar à API OCDS do UK Contracts Finder.
- **Fluxo de Trabalho de Agentes:**
    - **Agente Scout:** Coleta e normaliza dados JSON brutos.
    - **Agente Analyst:** Filtra oportunidades com base em palavras-chave e requisitos técnicos, bem como possíveis parcerias com empresas ganhadoras de licitações.
- **Ciclo de 12 Horas:** Executar lotes automatizados duas vezes ao dia para garantir a atualidade dos dados.
- **Logs de Auditoria:** Manter logs de todas as oportunidades coletadas e analisadas para conformidade e depuração.
- **Infraestrutura Segura:** Implantar usando as melhores práticas da AWS (IAM de menor privilégio, Secrets Manager) e utilizando a solução Serveless da AWS.

## 4. Anti-Escopo (O que o sistema NÃO FARÁ)
- **Lances Automatizados:** O sistema NÃO enviará propostas ou interagirá com portais governamentais além da recuperação de dados.
- **Licitações Não-Tecnológicas:** Licitações de construção civil, logística ou serviços não digitais serão descartadas.
- **Aconselhamento Jurídico:** A análise da IA é apenas para inteligência de negócios e não constitui aconselhamento jurídico de licitação.
- **Autenticação de Usuário:** Nenhum sistema de login para a fase de recuperação de dados para manter a simplicidade de "Dados Abertos".

## 5. Fluxo de Dados
1. **Gatilho:** CloudWatch Events / Cron aciona o fluxo de trabalho a cada 12 horas, ou demandado pela interface de administração pela aplicação feita em React.
2. **Ingestão:** A `API Tool` em Python solicita dados ao UK Contracts Finder (OCDS).
3. **Processamento (Scout):** O JSON bruto é analisado; duplicatas são removidas.
4. **Análise (Analyst):** O LLM avalia a descrição/tags em relação aos critérios de licitações que envolvam "Desenvolvimento de Software".
5. **Saída:** Oportunidades qualificadas são armazenadas (S3/Banco de Dados) e notificadas ao usuário na interface da aplicação e enviado por e-mail ou whatsapp.

## 6. Objetivos de Nível de Serviço (SLOs)
- **Atualidade dos Dados:** Novas licitações devem ser processadas em até 5 minutos após o gatilho de 12 horas.
- **Latência de Análise:** O tempo total de processamento por lote (máx. 100 avisos) deve ser inferior a 2 minutos.
- **Disponibilidade:** O serviço de consulta deve ter 99,5% de tempo de atividade (excluindo inatividade da API externa).
- **Segurança:** 100% das chaves de API e tokens internos devem ser rotacionados via AWS Secrets Manager.

## 7. Consumidores e Stakeholders
- **Equipes de Vendas:** Usuários primários que consomem os relatórios de leads filtrados.
- **Arquitetos de Soluções:** Usam os dados para entender os requisitos técnicos do mercado.
- **DevOps/SRE:** Responsáveis pela manutenção do pipeline AWS e orquestração do Open Claw.
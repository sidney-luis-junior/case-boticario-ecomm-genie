# 🧞‍♂️ E-comm Genie: Fundação Semântica para GenAI

**Repositório:** `case-boticario-ecomm-genie`
**Versão:** 1.1.0
**Núcleo:** Estruturante — Especialista de Dados

---

## 1. Visão Geral do Projeto

Este repositório contém a arquitetura da **Camada Semântica** projetada para sustentar o **E-comm Genie**, uma GenAI integrada ao canal `#fale-com-dados` no Slack. O objetivo desta fundação é garantir que o modelo de linguagem (LLM) consuma dados de performance de vendas com total acurácia, governança e zero risco de "alucinações" numéricas.

---

## 2. Arquitetura Proposta

A solução é construída sobre dois pilares complementares:

**Data Transformation (`procedure_camada_semantica.sql`):** Uma Stored Procedure que consome a tabela bruta `tb_vendas_bruta`, padroniza strings (tipagem de combos, normalização de mídia), trata valores nulos, neutraliza estornos negativos e aplica regras de negócio (flag `flg_venda_valida`).

**Semantic Model (`semantic_schema.yaml`):** Arquivo de metadados legível por máquina que define o contrato entre os dados e o LLM. Mapeia claramente o que é uma **Dimensão** (filtro/quebra), o que é uma **Métrica** (cálculo/agregação) e quais filtros são obrigatórios por padrão. Inclui seção explícita de governança listando campos omitidos e limitações técnicas conhecidas.

```
tb_vendas_bruta (raw)
       │
       ▼
sp_build_tb_vendas_semantica()    ← procedure_camada_semantica.sql
       │
       ▼
tb_vendas_semantica               ← tabela particionada e clusterizada
       │
       ▼
semantic_schema.yaml                ← contrato semântico para o LLM
       │
       ▼
E-comm Genie (Slack)                ← respostas em linguagem natural
```

---

## 3. 🛡️ Governança de Dados e Privacidade (LGPD)

Decisões críticas de segurança foram tomadas em conformidade estrita com a LGPD e as políticas de segurança da informação:

**Omissão do CPF Real:** A coluna `cpf_consumidor_full` foi explicitamente excluída da view semântica em todos os níveis — SQL, YAML e documentação. O LLM não possui nenhuma rota de acesso a esse dado.

**Identificação Segura para CRM:** Análises de top consumidores e segmentação de clientes utilizam exclusivamente `cpf_hash`, garantindo anonimização total na ponta do Slack.

**Auditabilidade:** A seção `governance.omitted_fields` do YAML registra formalmente o que foi excluído e por quê, tornando o contrato de privacidade rastreável sem necessidade de leitura do código SQL.

---

## 4. ⚡ Otimização de Custos e Performance (BigQuery)

A tabela final foi configurada para minimizar custo de processamento nas consultas diárias do E-comm Genie:

**Particionamento por `dt_venda`:** Análises de performance quase sempre incluem filtros de tempo (ontem, último mês, YoY). O BigQuery lê apenas as partições relevantes, reduzindo bytes processados e custo por query.

**Clusterização por `marca_ind, regiao`:** Otimiza queries frequentes de Diretores Comerciais (share por marca) e Gerentes Regionais (performance por região), que representam o maior volume de requisições no canal.

**`SAFE_CAST` + `COALESCE`:** Tratamento defensivo de todos os campos financeiros evita erros silenciosos em dados sujos oriundos de integrações produtivas.

**Filtro padrão via `default_filter`:** A flag `flg_venda_valida = 1` é aplicada automaticamente em todas as métricas de receita, eliminando a necessidade de filtros manuais em cada query do LLM — e o risco de agregação de dados inválidos.

---

## 5. 🔢 Cobertura das Perguntas de Negócio

| # | Pergunta | Status | Observação |
|---|---|---|---|
| Q1 | Faturamento ontem vs LY — valor e volume | ✅ Coberta | `receita_faturada` + `volume_pedidos` + filtro por `data_venda` |
| Q2 | Top 10 CPFs em Perfumaria no último mês | ⚠️ Parcial | `cliente_hash` disponível; "Perfumaria" = `CAT-XX` — ver LIM-01 |
| Q3 | SKU Malbec — individual vs combo no Ciclo 01 | ⚠️ Parcial | `formato_venda` + `codigo_ciclo` disponíveis; nome do SKU = codificado — ver LIM-01 |
| Q4 | Melhor ticket médio no Nordeste em dezembro | ✅ Coberta | `ticket_medio` + `regiao_geografica` + `data_venda` + `default_filter` |
| Q5 | Receita de buscadores de IA vs Google Orgânico | ❌ Indisponível | Dataset de 2022 sem tráfego de IA — ver LIM-02 |
| Q6 | Share de faturamento por marca este mês | ✅ Coberta | `receita_faturada` + `marca` + `data_venda` |
| Q7 | ROI da campanha de cupons do Instagram | ⚠️ Parcial | Receita por cupom disponível; Ad Spend não ingerido — ver LIM-03 |

---

## 6. 🚀 Antecipação de Demandas do E-commerce

Além das requisições mapeadas no momento zero, o schema semântico foi enriquecido proativamente:

**Métricas de O2O (Online to Offline):** Dimensão `modalidade_logistica` cruza as flags de `flg_pedidos_pickup` e `flg_pedidos_cd` para análises de "Retirada em Loja" vs "Entrega Tradicional".

**Controle de Margem:** `taxa_de_desconto_percentual` mede a agressividade promocional (desconto / receita faturada), usando `vlr_receita_faturada` como denominador — mais estável e representativo do que a receita bruta.

**Heatmap de Vendas:** Dimensão `hora_da_venda` extrai a hora da transação para suportar análises de pico de tráfego pelo time de TI e alocação de budget de mídia.

**Monitoramento de Cancelamentos:** Métricas `pedidos_cancelados` e `taxa_cancelamento` para times de Operações e Antifraude.

**Granularidade Geográfica:** `estado_uf` e `cidade` complementam `regiao_geografica` para análises logísticas ou tributárias de alta resolução.

---

## 7. ⚠️ Limitações Técnicas Conhecidas

### LIM-01 — Campos de produto e marca estão anonimizados

Os campos `marca_ind` (ex: `MARCA-9`), `categoria_final_nivel1` (ex: `CAT-13`) e `cod_material` (ex: `SKU-XXXXXXX`) estão codificados na base transacional de origem.

**Impacto direto:** O LLM não consegue resolver perguntas com nomes reais como "Eudora", "Perfumaria" ou "Malbec Desodorante Colônia" sem uma tabela de-para (*lookup*).

**Perguntas afetadas:** Q2 (top consumidores de "Perfumaria") e Q3 (SKU pelo nome comercial).

**Recomendação para V2:** Integrar tabela dimensional `dim_produto` e `dim_marca` com mapeamento `código → nome real`, ingerida via pipeline da área de Catálogo.

### LIM-02 — Buscadores de IA ausentes no dataset histórico (2022)

ChatGPT foi lançado em novembro/2022 e Perplexity estava em fase beta. Nenhum aparece como fonte de tráfego na base atual. A pergunta Q5 não pode ser respondida com os dados históricos disponíveis.

**Recomendação:** A estrutura semântica já suporta essa métrica — bastará garantir que os dados futuros sejam ingeridos com os UTM Sources corretos (ex: `perplexity`, `chatgpt`).

### LIM-03 — ROI de campanhas de mídia paga indisponível

A base transacional captura a receita gerada e os cupons utilizados, mas não o Ad Spend das plataformas. O cálculo de ROI real exige integração com a API do Meta Ads e/ou Google Ads.

**Impacto direto:** Q7 (ROI de cupons do Instagram) não pode ser respondida na V1.

**Mitigação atual:** O Genie pode informar a *receita atribuída* a cupons do Instagram (filtrando por `des_cupom` e `des_midia_canal`), mas o ROI exato fica bloqueado.

**Recomendação para V2:** Integrar tabela `fato_ad_spend` com dados de custo por plataforma e data, juntável com a camada semântica por `dt_venda`.

### LIM-04 — Valores negativos em `vlr_receita_bruta_omni` (estornos)

Registros com `vlr_receita_bruta_omni < 0` representam estornos ou devoluções do sistema produtivo. A procedure os neutraliza via `GREATEST(..., 0)` nas métricas de receita bruta agregada e os sinaliza com `flg_estorno = 1` para análises isoladas.

---

## 8. 📁 Estrutura do Repositório

```
case-boticario-ecomm-genie/
├── procedure_camada_semantica.sql   # Stored Procedure BigQuery (ETL + limpeza)
├── semantic_schema.yaml             # Contrato semântico para o LLM
├── comunicado_release.md            # Comunicado interno de release
├── comunicado_release_slack.png     # Preview visual do comunicado no Slack
└── README.md                        # Este arquivo
```

---

## 9. 🚀 Como Usar

**1. Executar a procedure** para popular a tabela semântica:

```sql
CALL `projeto_de_faturamento.dataset.sp_build_tb_vendas_semantica`();
```

**2. Verificar a tabela gerada:**

```sql
SELECT * FROM `projeto_de_faturamento.dataset.tb_vendas_semantica`
WHERE flg_venda_valida = 1
LIMIT 100;
```

**3. Conectar o LLM:** Passar o arquivo `semantic_schema.yaml` como system prompt de contexto para o E-comm Genie, garantindo que o modelo conheça as dimensões disponíveis, as métricas oficiais e o filtro padrão obrigatório.

---

## 10. 🗺️ Roadmap — Próximas Evoluções (V2)

| Prioridade | Item | Benefício |
|---|---|---|
| Alta | Tabela `dim_produto` + `dim_marca` (de-para de códigos) | Desbloqueia Q2 e Q3 completas |
| Alta | Integração `fato_ad_spend` (Meta Ads + Google Ads) | Desbloqueia ROI real (Q7) |
| Média | UTM Sources para buscadores de IA | Desbloqueia Q5 em dados futuros |
| Média | Camada de acesso controlado para `cpf_consumidor_full` | Auditorias com rastreabilidade |
| Baixa | Partição adicional por `marca_ind` | Redução de custo em queries de marca |

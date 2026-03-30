# case-boticario-ecomm-genie
Repositório destinado à resolução do Case Técnico de Especialista de Dados do Grupo Boticário.

# 🧞‍♂️ E-comm Genie: Fundação Semântica para GenAI

## 1. Visão Geral do Projeto
Este repositório contém a arquitetura da Camada Semântica projetada para sustentar o **E-comm Genie**, uma GenAI integrada ao canal `#fale-com-dados` no Slack. O objetivo desta fundação é garantir que o modelo de linguagem (LLM) consuma dados de performance de vendas com total acurácia, governança e zero risco de "alucinações" numéricas.

## 2. Arquitetura Proposta
A solução foi desenhada no padrão **BigQuery** e divide-se em duas etapas principais:
1. **Data Transformation (SQL Procedure):** Uma Stored Procedure que consome a tabela bruta `tb_vendas`, padroniza strings (ex: tipagem de combos), trata valores nulos e aplica regras de negócio (ex: flag de vendas válidas).
2. **Semantic Model (YAML):** Um arquivo de metadados legível por máquina que define os limites do LLM, mapeando claramente o que é uma "Dimensão" (filtro/quebra) e o que é uma "Métrica" (cálculo/agregação).

## 3. 🛡️ Governança de Dados e Privacidade (LGPD)
Decisões críticas de segurança foram tomadas para proteger dados sensíveis, em estrita conformidade com a LGPD e as políticas de segurança da informação:
* **Omissão do CPF Real:** A coluna bruta `cpf_consumidor_full` foi explicitamente excluída da view semântica.
* **Identificação Segura:** Para responder a perguntas analíticas de CRM (ex: "Top 10 consumidores"), o modelo consome exclusivamente a coluna `cpf_hash`, garantindo a anonimização total do cliente na ponta do Slack.

## 4. ⚡ Otimização de Custos e Performance
Para garantir que as requisições diárias no BigQuery tenham o menor custo de processamento e a maior velocidade possível:
* A tabela final foi **Particionada** por `dt_venda`, uma vez que análises de performance quase sempre envolvem filtros de tempo (ex: YoY, mês passado).
* A tabela foi **Clusterizada** por `marca_ind` e `regiao`, otimizando a leitura de dados pontuais solicitados por Diretores Comerciais e Gerentes Regionais.

## 5. 🚀 Antecipação de Demandas do E-commerce
Para além das requisições mapeadas no momento zero do produto, o modelo de metadados (`semantic_schema.yaml`) foi enriquecido proativamente com:
* **Métricas de O2O (Online to Offline):** Criação da dimensão `modalidade_logistica`, cruzando as flags de `flg_pedidos_pickup` e `flg_pedidos_cd` para análises de "Retirada em Loja" vs "Entrega Tradicional".
* **Controle de Margem:** Implementação da `taxa_de_desconto_percentual`, cruzando a receita bruta com os descontos (`vlr_venda_desconto`).
* **Heatmap de Vendas:** Extração da hora exata da venda (`dt_hora_venda`) para suportar análises de pico de tráfego do time de TI e Mídia.

## 6. ⚠️ Limitações Técnicas Conhecidas
1. Foi solicitada a métrica de **ROI (Return on Investment) de campanhas do Instagram**. 
* **Limitação:** A base transacional atual não possui a ingestão dos custos de mídia paga (Ad Spend) das plataformas sociais. 
* **Mitigação Atual:** O Genie consegue informar a *Receita Faturada* gerada por cupons do Instagram, mas o cálculo exato do ROI fica impossibilitado nesta V1. A recomendação é integrar a API do Meta Ads à malha de dados em uma sprint futura para desbloquear essa métrica ou um JOIN com alguma tabela que ja traga essa informação.

2. Uma das perguntas (a pergunta 3) refere-se a **descrição/marca do produto**.
* **Limitação:** Ausência de descrição de Produtos (Cadastro): A requisição de negócio exige buscas por nomes textuais de produtos (ex: "SKU Malbec Desodorante Colônia"). A base transacional `tb_vendas` possui apenas os códigos identificadores (`cod_material`).
* **Mitigação Atual:** O Genie conseguirá filtrar se o usuário digitar o código exato do SKU. Para buscas por linguagem natural ("Nome do Produto"), é mandatório o enriquecimento desta camada semântica via JOIN com a uma tabela que possua a nomeclatura da descrição em uma futura iteração.

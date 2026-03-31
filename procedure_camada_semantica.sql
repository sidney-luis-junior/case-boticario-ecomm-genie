-- =============================================================================
-- E-comm Genie: Camada Semântica — SQL Procedure
-- Projeto: case-boticario-ecomm-genie
-- Autor: Especialista de Dados | Núcleo Estruturante
-- Versão: 1.1.0
-- Descrição: Consome a tabela bruta tb_vendas, aplica limpeza, padronização
--            e regras de negócio, gerando a fato_vendas_semantica como
--            fonte única da verdade para o E-comm Genie (LLM).
-- =============================================================================

CREATE OR REPLACE PROCEDURE `projeto-de-faturamento.dataset.sp_build_tb_vendas_semantica`()
BEGIN

  -- ============================================================================
  -- ETAPA 1: Criação da tabela semântica final
  -- OTIMIZAÇÃO BigQuery:
  --   PARTITION BY dt_venda  → filtra dados por data sem varredura total
  --   CLUSTER BY marca_ind, regiao → reduz custo em queries por marca e região
  -- ============================================================================

  CREATE OR REPLACE TABLE `projeto-de-faturamento.dataset.tb_vendas_semantica`
  PARTITION BY dt_venda
  CLUSTER BY marca_ind, regiao
  AS

  WITH dados_limpos AS (
    SELECT

      -- -----------------------------------------------------------------------
      -- 1. CHAVES DE IDENTIFICAÇÃO
      -- -----------------------------------------------------------------------
      cod_un_negocio,
      cod_pedido,
      cod_material,
      cod_material_pai,

      -- -----------------------------------------------------------------------
      -- 2. PADRONIZAÇÃO DE STRINGS
      -- Garante que 'combo', 'COMBO' e 'individual' fiquem normalizados.
      -- -----------------------------------------------------------------------
      UPPER(TRIM(apresentacao_combo)) AS apresentacao_combo,

      -- -----------------------------------------------------------------------
      -- 3. TRATAMENTO DE DATAS
      -- SAFE_CAST evita falha silenciosa em formatos inesperados.
      -- -----------------------------------------------------------------------
      SAFE_CAST(dt_venda AS DATE)           AS dt_venda,
      SAFE_CAST(dt_hora_venda AS TIMESTAMP) AS dt_hora_venda,

      -- -----------------------------------------------------------------------
      -- 4. DIMENSÕES DE CICLO COMERCIAL
      -- Ambos os campos são mantidos: cod_ciclo (ex: 202201) para filtros
      -- programáticos e des_ciclo (ex: 'REGULAR') para leitura humana.
      -- -----------------------------------------------------------------------
      cod_ciclo,
      des_ciclo,

      -- -----------------------------------------------------------------------
      -- 5. CLASSIFICAÇÕES DE PRODUTO E LOCALIDADE
      -- Atenção: marca_ind e categoria_final_nivel1 estão anonimizados
      -- (ex: MARCA-9, CAT-13). Consultar tabela de-para para nomes reais.
      -- -----------------------------------------------------------------------
      marca_ind,
      categoria_final_nivel1,
      uf,
      regiao,
      des_cidade,

      -- -----------------------------------------------------------------------
      -- 6. TRATAMENTO FINANCEIRO
      -- COALESCE → substitui nulos por 0.0 para segurança de cálculo.
      -- GREATEST  → neutraliza valores negativos (estornos/devoluções) que
      --             poluiriam métricas de receita bruta agregada.
      --             Registros negativos são preservados via flg_estorno.
      -- -----------------------------------------------------------------------
      GREATEST(
        COALESCE(SAFE_CAST(vlr_receita_bruta_omni AS FLOAT64), 0.0),
        0.0
      )                                                            AS vlr_receita_bruta_omni,
      COALESCE(SAFE_CAST(vlr_receita_faturada AS FLOAT64), 0.0)   AS vlr_receita_faturada,
      COALESCE(SAFE_CAST(vlr_venda_pago AS FLOAT64), 0.0)         AS vlr_venda_pago,
      COALESCE(SAFE_CAST(vlr_venda_desconto AS FLOAT64), 0.0)     AS vlr_venda_desconto,

      -- Flag de estorno: identifica registros com receita bruta negativa
      -- para análises de devolução sem contaminar os agregados principais.
      IF(SAFE_CAST(vlr_receita_bruta_omni AS FLOAT64) < 0, 1, 0) AS flg_estorno,

      -- -----------------------------------------------------------------------
      -- 7. STATUS E REGRAS DE NEGÓCIO
      -- flg_venda_valida é a flag mestra: 1 = pedido aprovado e faturado.
      -- TODAS as métricas de receita devem ser filtradas por ela.
      -- -----------------------------------------------------------------------
      status_oms,
      SAFE_CAST(flg_faturada  AS INT64) AS flg_faturada,
      SAFE_CAST(flg_aprovada  AS INT64) AS flg_aprovada,
      IF(
        SAFE_CAST(flg_faturada AS INT64) = 1
        AND SAFE_CAST(flg_aprovada AS INT64) = 1,
        1, 0
      )                                  AS flg_venda_valida,

      -- -----------------------------------------------------------------------
      -- 8. DADOS DE TRÁFEGO E MÍDIA
      -- LOWER(TRIM()) normaliza variações de case em des_midia_canal.
      -- -----------------------------------------------------------------------
      des_canal_venda_final,
      fonte_de_trafego_nivel_1,
      LOWER(TRIM(des_midia_canal)) AS des_midia_canal,
      des_cupom,

      -- -----------------------------------------------------------------------
      -- 9. DADOS LOGÍSTICOS (O2O)
      -- -----------------------------------------------------------------------
      SAFE_CAST(flg_pedidos_cd     AS INT64) AS flg_pedidos_cd,
      SAFE_CAST(flg_pedidos_pickup AS INT64) AS flg_pedidos_pickup,

      -- -----------------------------------------------------------------------
      -- 10. GOVERNANÇA E PRIVACIDADE (LGPD) — CRÍTICO
      -- cpf_hash: identificador anonimizado, único campo de CRM exposto ao LLM.
      -- cpf_consumidor_full: PROPOSITALMENTE EXCLUÍDO.
      --   Justificativa: dado pessoal sensível. Exposição ao LLM via Slack
      --   viola a LGPD (Art. 46) e as políticas internas de segurança.
      --   Acesso restrito a sistemas de auditoria com controles de acesso.
      -- -----------------------------------------------------------------------
      cpf_hash

    FROM `projeto-de-faturamento.dataset.tb_vendas_bruta`
  )

  SELECT * FROM dados_limpos;

END;

-- =============================================================================
-- EXEMPLO DE EXECUÇÃO
-- Execute após criar a procedure para popular a tabela semântica.
-- =============================================================================
-- CALL `projeto-de-faturamento.dataset.sp_build_tb_vendas_semantica`();

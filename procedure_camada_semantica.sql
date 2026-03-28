-- Criação da Procedure
CREATE OR REPLACE PROCEDURE `projeto-de-faturamento.dataset.sp_build_fato_vendas_semantica`()
BEGIN
  -- Cria (ou substitui) a tabela final que o LLM vai consumir
  CREATE OR REPLACE TABLE `seu_projeto.seu_dataset.fato_vendas_semantica`
  -- OTIMIZAÇÃO DE CUSTO/PERFORMANCE NO BIGQUERY
  PARTITION BY dt_venda
  CLUSTER BY marca_ind, regiao
  AS
  
  -- CTE para limpar e organizar os dados
  WITH dados_limpos AS (
    SELECT
      -- 1. Chaves de Identificação
      cod_un_negocio,
      cod_pedido,
      cod_material,
      cod_material_pai,
      
      -- 2. Padronização de Texto (Garante que 'combo', 'COMBO' e 'individual' fiquem iguais)
      UPPER(TRIM(apresentacao_combo)) AS apresentacao_combo,
      
      -- 3. Tratamento de Datas
      SAFE_CAST(dt_venda AS DATE) AS dt_venda,
      SAFE_CAST(dt_hora_venda AS TIMESTAMP) AS dt_hora_venda,
      cod_ciclo,
      des_ciclo,
      
      -- 4. Classificações de Produto e Localidade
      marca_ind,
      categoria_final_nivel1,
      uf,
      regiao,
      des_cidade,
      
      -- 5. Tratamento Financeiro (Substitui nulos/vazios por ZERO para a IA não errar contas)
      COALESCE(SAFE_CAST(vlr_receita_bruta_omni AS FLOAT64), 0.0) AS vlr_receita_bruta_omni,
      COALESCE(SAFE_CAST(vlr_receita_faturada AS FLOAT64), 0.0) AS vlr_receita_faturada,
      COALESCE(SAFE_CAST(vlr_venda_pago AS FLOAT64), 0.0) AS vlr_venda_pago,
      COALESCE(SAFE_CAST(vlr_venda_desconto AS FLOAT64), 0.0) AS vlr_venda_desconto,
      
      -- 6. Status e Regras de Negócio
      status_oms,
      SAFE_CAST(flg_faturada AS INT64) AS flg_faturada,
      SAFE_CAST(flg_aprovada AS INT64) AS flg_aprovada,
      -- Criada uma flag para facilitar a vida da IA: 1 para venda válida, 0 para inválida
      IF(SAFE_CAST(flg_faturada AS INT64) = 1 AND SAFE_CAST(flg_aprovada AS INT64) = 1, 1, 0) AS flg_venda_valida,
      
      -- 7. Dados de Tráfego e Mídia (Essencial para cruzamentos de Marketing)
      des_canal_venda_final,
      fonte_de_trafego_nivel_1,
      LOWER(TRIM(des_midia_canal)) AS des_midia_canal,
      des_cupom,
      
      -- 8. Dados Logísticos
      SAFE_CAST(flg_pedidos_cd AS INT64) AS flg_pedidos_cd,
      SAFE_CAST(flg_pedidos_pickup AS INT64) AS flg_pedidos_pickup,
      
      -- 9. GOVERNANÇA E SEGURANÇA DE DADOS (CRÍTICO)
      cpf_hash
      
      -- ATENÇÃO: A coluna 'cpf_consumidor_full' foi PROPOSITALMENTE EXCLUÍDA desta query.
      -- O LLM não deve ter acesso a dados pessoais sensíveis abertos (LGPD).
      
    FROM `projeto-de-faturamento.dataset.tb_vendas_bruta`
  )
  
  -- Seleciona os dados tratados para preencher a nova tabela
  SELECT * FROM dados_limpos;
  
END;

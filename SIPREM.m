% =========================================================
% fuzzy_promethee_s2_geldermann_comparativo.m
% graficos mais importantes: 1 4 5 8 14 e 16
% CENÁRIOS:
%   S1 = pesos fuzzy fixos
%        + avaliações médias fuzzy dos especialistas
%        + Fuzzy PROMETHEE II
%
%   S2 = FAHP trapezoidal individual por especialista
%        + Fuzzy PROMETHEE II individual
%        + agregação posterior dos fluxos líquidos fuzzy
%
% REPRESENTAÇÃO DOS NÚMEROS FUZZY:
% Trapézios armazenados no formato [a b c d], onde:
%   a = suporte inferior
%   b = núcleo inferior
%   c = núcleo superior
%   d = suporte superior
% =========================================================

clear; clc; close all;

%% =========================================================
% CONFIGURAÇÃO AUTOMÁTICA DAS FIGURAS
%% =========================================================

% Identificador único para cada execução
identificador_execucao = datestr(now,'yyyy-mm-dd_HH-MM-SS');

% Pasta específica desta execução
pasta_figuras = fullfile( ...
    pwd, ...
    ['Figuras_' identificador_execucao]);

if ~exist(pasta_figuras,'dir')
    mkdir(pasta_figuras);
end

% Todas as figuras ficam ocultas por padrão.
% Apenas as três figuras principais serão mostradas.
set(groot,'defaultFigureVisible','off');

fprintf('\nPasta das figuras desta execução:\n%s\n',pasta_figuras);
%% ---------------------------------------------------------
% 1. CONFIGURAÇÕES GERAIS
% ---------------------------------------------------------
input_file = 'dados_requisitos_lista.xlsx';
all_sheets = sheetnames(input_file);
all_sheets = all_sheets(1:end-1); % IGNORA ÚLTIMA
nExperts = numel(all_sheets);

nCrit = 5;
crit_names = {'Impacto', 'Custo', 'CAPACIDADE NACIONAL DE IMPLEMENTAÇÃO', 'Prazo', 'RiscoVerif'};

% Direção dos critérios: +1 = maximizar, -1 = minimizar
critDir = [1, -1, 1, -1, -1];

% Funções de preferência: 1 = Usual, 4 = Level
pref_types = [1, 4, 4, 4, 4];
%pref_types = [5, 5, 5, 5, 5];

% Limites das escalas
% Impacto 1-7, Custo 1-7, Capacidade Técnica Nacional para Implementação
% 1-7, Prazo 1-7, Risco Verif 1-7
scale_max = [7, 7, 7, 7, 7];
scale_min = [1, 1, 1, 1, 1];

% amplitude das escalas
A_scale = scale_max - scale_min;

% limiares automáticos
q_vals = [0, 0.06*A_scale(2), 0.06*A_scale(3), 0.06*A_scale(4), 0.06*A_scale(5)];
p_vals = [0, 0.21*A_scale(2), 0.21*A_scale(3), 0.21*A_scale(4), 0.21*A_scale(5)];



% Tabelas trapezoidais para fuzzificação das avaliações
TFN_eval_5 = [
    1.0  1.0  1.5  2.0
    1.5  2.0  2.0  2.5
    2.0  2.5  3.0  3.5
    3.0  3.5  4.0  4.5
    4.0  4.5  5.0  5.0
];

TFN_eval_7 = [
    1.0  1.0  1.5  2.0
    1.0  1.5  2.5  3.0
    2.0  2.5  3.5  4.0
    3.0  3.5  4.5  5.0
    4.0  4.5  5.5  6.0
    5.0  5.5  6.5  7.0
    6.0  6.5  7.0  7.0
];

TFN_eval_9 = [
    1.0  1.0  1.5  2.0
    1.0  1.5  2.5  3.0
    2.0  2.5  3.5  4.0
    3.0  3.5  4.5  5.0
    4.0  4.5  5.0  5.5
    5.0  5.5  6.5  7.0
    6.0  6.5  7.5  8.0
    7.0  7.5  8.5  9.0
    8.0  8.5  9.0  9.0
];


%% ---------------------------------------------------------
% 2. PESOS FUZZY CALCULADOS AUTOMATICAMENTE VIA FAHP
% ---------------------------------------------------------

% Pesos fuzzy fixos do cenário S1 (institucional/base)
w_s1_fuzzy = [
    0.4413    0.5082    0.6573    0.7453
    0.1000    0.1160    0.1565    0.1846
    0.0956    0.1115    0.1507    0.1773
    0.0638    0.0734    0.0988    0.1174
    0.0552    0.0629    0.0834    0.0983
];

% S2 = pesos dos especialistas do estudo de caso
[w_fuzzy_group, w_group_defuzz, info_s2]=get_ws1_fuzzy_from_fahp_express('F_AHP_A.xlsx');

disp('====================================================');
disp('Pesos fuzzy do grupo (FAHP trapezoidal) - calculados automaticamente');
for k = 1:nCrit
    fprintf('%-12s : [%.4f %.4f %.4f %.4f]\n', ...
        crit_names{k}, w_fuzzy_group(k,1), w_fuzzy_group(k,2), ...
        w_fuzzy_group(k,3), w_fuzzy_group(k,4));
end
disp(' ');
disp('Pesos defuzzificados do grupo:');
for k = 1:nCrit
    fprintf('%-12s : %.4f\n', crit_names{k}, w_group_defuzz(k));
end
disp(' ');
disp('Pesos fuzzy fixos S1:');
for k = 1:nCrit
    fprintf('%-12s : [%.4f %.4f %.4f %.4f]\n', ...
        crit_names{k}, w_s1_fuzzy(k,1), w_s1_fuzzy(k,2), ...
        w_s1_fuzzy(k,3), w_s1_fuzzy(k,4));
end
disp('====================================================');


%% ---------------------------------------------------------
% 4. LEITURA DAS AVALIAÇÕES DOS REQUISITOS
% ---------------------------------------------------------
T0 = readtable(input_file, 'Sheet', all_sheets{1}, 'VariableNamingRule', 'preserve');
IDs = T0{:,1};
data0 = T0{:,3:(2+nCrit)};
[nReq, ~] = size(data0);

req_labels = arrayfun(@(x) sprintf('R%d', x), 1:nReq, 'UniformOutput', false);

% média das avaliações - usada apenas no cenário S1
data_accum = zeros(nReq, nCrit);
for e = 1:nExperts
    Te = readtable(input_file, 'Sheet', all_sheets{e}, 'VariableNamingRule', 'preserve');
   
    data_raw = table2cell(Te(:,3:(2+nCrit)));

data_e = zeros(size(data_raw));

for i = 1:size(data_raw,1)
    for k = 1:size(data_raw,2)
        data_e(i,k) = linguistic2num(data_raw{i,k});
    end
end
    data_accum = data_accum + data_e;
end
data_group = data_accum / nExperts;

%% ---------------------------------------------------------
% 4A. MATRIZES DE AVALIAÇÃO DOS ESPECIALISTAS + DISPERSÃO
% ---------------------------------------------------------
data_all = zeros(nReq, nCrit, nExperts);
impacto_ind = zeros(nReq, nExperts);

for e = 1:nExperts
    Te = readtable(input_file, 'Sheet', all_sheets{e}, 'VariableNamingRule', 'preserve');
    data_raw = Te{:,3:(2+nCrit)};

data_e = zeros(size(data_raw));

for i = 1:size(data_raw,1)
    for k = 1:size(data_raw,2)
        data_e(i,k) = linguistic2num(data_raw{i,k});
    end
end
    data_all(:,:,e) = data_e;
    impacto_ind(:,e) = data_e(:,1);   % coluna 1 = Impacto
end

% Métricas de dispersão em Impacto
impacto_std   = std(impacto_ind, 0, 2);
impacto_range = max(impacto_ind, [], 2) - min(impacto_ind, [], 2);

% Métricas de dispersão global por requisito
std_por_crit_req   = zeros(nReq, nCrit);
range_por_crit_req = zeros(nReq, nCrit);

for i = 1:nReq
    for k = 1:nCrit
        vals = squeeze(data_all(i,k,:));
        std_por_crit_req(i,k)   = std(vals, 0, 1);
        range_por_crit_req(i,k) = max(vals) - min(vals);
    end
end

disp_std_media_req   = mean(std_por_crit_req, 2);
disp_range_media_req = mean(range_por_crit_req, 2);

%% ---------------------------------------------------------
% 5. AGREGAÇÃO FUZZY DAS AVALIAÇÕES DOS ESPECIALISTAS
% ---------------------------------------------------------

F = zeros(nReq,nCrit,4);

for e = 1:nExperts

    Te = readtable(input_file,...
                   'Sheet',all_sheets{e},...
                   'VariableNamingRule','preserve');

    data_raw = Te{:,3:(2+nCrit)};

    data_e = zeros(size(data_raw));

    for i = 1:size(data_raw,1)
        for k = 1:size(data_raw,2)

            data_e(i,k) = linguistic2num(data_raw{i,k});

        end
    end

    for i = 1:nReq

        for k = 1:nCrit

            val = data_e(i,k);

            trap = fuzzifyByScale( ...
                val,...
                scale_max(k),...
                TFN_eval_5,...
                TFN_eval_7,...
                TFN_eval_9);

            F(i,k,:) = squeeze(F(i,k,:))' + trap;

        end
    end
end

F = F / nExperts;
%% ---------------------------------------------------------
% 6. CENÁRIO S1 - pesos fuzzy fixos + avaliações médias
% ---------------------------------------------------------
PI_base = zeros(nReq, nReq, 4);

for i = 1:nReq
    for j = 1:nReq
        if i == j
            continue;
        end

        pi_ij = [0, 0, 0, 0];

        for k = 1:nCrit
            Ai = squeeze(F(i,k,:))';
            Bj = squeeze(F(j,k,:))';

            if critDir(k) == 1
                D = trap_sub(Ai, Bj);
            else
                D = trap_sub(Bj, Ai);
            end

            Pk = pref_trap(D, pref_types(k), q_vals(k), p_vals(k));
            Wk = w_s1_fuzzy(k,:);

            term = trap_mul_geldermann(Wk, Pk);
            pi_ij = trap_add(pi_ij, term);
        end

        PI_base(i,j,:) = pi_ij;
    end
end

Phi_plus_base_fuzzy  = zeros(nReq, 4);
Phi_minus_base_fuzzy = zeros(nReq, 4);
Phi_net_base_fuzzy   = zeros(nReq, 4);

Phi_plus_base  = zeros(nReq, 1);
Phi_minus_base = zeros(nReq, 1);
phi_liq_base   = zeros(nReq, 1);

for i = 1:nReq
    sumP = [0, 0, 0, 0];
    sumM = [0, 0, 0, 0];

    for j = 1:nReq
        if i == j
            continue;
        end
        sumP = trap_add(sumP, squeeze(PI_base(i,j,:))');
        sumM = trap_add(sumM, squeeze(PI_base(j,i,:))');
    end

    avgP = trap_scalar_div(sumP, (nReq - 1));
    avgM = trap_scalar_div(sumM, (nReq - 1));
    netF = trap_sub(avgP, avgM);

    Phi_plus_base_fuzzy(i,:)  = avgP;
    Phi_minus_base_fuzzy(i,:) = avgM;
    Phi_net_base_fuzzy(i,:)   = netF;

    Phi_plus_base(i)  = defuzz_coa(avgP);
    Phi_minus_base(i) = defuzz_coa(avgM);
    phi_liq_base(i)   = defuzz_coa(netF);
end

%% ---------------------------------------------------------
% 7. S2 - PROMETHEE individual por especialista + agregação posterior
% ---------------------------------------------------------
rank_matrix = zeros(nReq, nExperts + 1);
col_names = [all_sheets(:); {'Grupo S2'}];

phi_net_experts       = zeros(nReq, nExperts);
Phi_plus_experts      = zeros(nReq, nExperts);
Phi_minus_experts     = zeros(nReq, nExperts);

Phi_plus_fuzzy_exp    = zeros(nReq, 4, nExperts);
Phi_minus_fuzzy_exp   = zeros(nReq, 4, nExperts);
Phi_net_fuzzy_exp     = zeros(nReq, 4, nExperts);

for e = 1:nExperts
    Te = readtable(input_file, 'Sheet', all_sheets{e}, 'VariableNamingRule', 'preserve');
    data_raw = Te{:,3:(2+nCrit)};

data_e = zeros(size(data_raw));

for i = 1:size(data_raw,1)
    for k = 1:size(data_raw,2)
        data_e(i,k) = linguistic2num(data_raw{i,k});
    end
end

    % fuzzificação das avaliações do especialista
    F_e = zeros(nReq, nCrit, 4);
    for i = 1:nReq
        for k = 1:nCrit
            val = data_e(i,k);

            trap = fuzzifyByScale(val, scale_max(k), TFN_eval_5, TFN_eval_7, TFN_eval_9);
        F_e(i,k,:) = trap;
        end
    end

    % pesos fuzzy individuais vindos da função FAHP
w_fuzzy_e = squeeze(info_s2.w_fuzzy_individual(:,:,e));

    % fuzzy PROMETHEE II individual
    [phi_plus_e, phi_minus_e, phi_net_e, phi_plus_fz_e, phi_minus_fz_e, phi_net_fz_e] = ...
        runFuzzyPrometheeTrap(F_e, w_fuzzy_e, critDir, pref_types, q_vals, p_vals);

    Phi_plus_experts(:,e)    = phi_plus_e;
    Phi_minus_experts(:,e)   = phi_minus_e;
    phi_net_experts(:,e)     = phi_net_e;

    Phi_plus_fuzzy_exp(:,:,e)  = phi_plus_fz_e;
    Phi_minus_fuzzy_exp(:,:,e) = phi_minus_fz_e;
    Phi_net_fuzzy_exp(:,:,e)   = phi_net_fz_e;

    rank_matrix(:,e) = nReq + 1 - tiedrank(phi_net_e);
end

% agregação posterior dos fluxos fuzzy individuais
Phi_plus_fuzzy  = zeros(nReq, 4);
Phi_minus_fuzzy = zeros(nReq, 4);
Phi_net_fuzzy   = zeros(nReq, 4);

Phi_plus  = zeros(nReq,1);
Phi_minus = zeros(nReq,1);
phi_net   = zeros(nReq,1);

for i = 1:nReq
    accP = [0 0 0 0];
    accM = [0 0 0 0];
    accN = [0 0 0 0];

    for e = 1:nExperts
        accP = trap_add(accP, squeeze(Phi_plus_fuzzy_exp(i,:,e))');
        accM = trap_add(accM, squeeze(Phi_minus_fuzzy_exp(i,:,e))');
        accN = trap_add(accN, squeeze(Phi_net_fuzzy_exp(i,:,e))');
    end

    Phi_plus_fuzzy(i,:)  = trap_scalar_div(accP, nExperts);
    Phi_minus_fuzzy(i,:) = trap_scalar_div(accM, nExperts);
    Phi_net_fuzzy(i,:)   = trap_scalar_div(accN, nExperts);

    Phi_plus(i)  = defuzz_coa(Phi_plus_fuzzy(i,:));
    Phi_minus(i) = defuzz_coa(Phi_minus_fuzzy(i,:));
    phi_net(i)   = defuzz_coa(Phi_net_fuzzy(i,:));
end

rank_matrix(:,end) = nReq + 1 - tiedrank(phi_net);

[~, ord_rows] = sort(rank_matrix(:,end), 'ascend');
rank_matrix_ord = rank_matrix(ord_rows,:);
req_labels_ord = req_labels(ord_rows);


% =========================================================
% DEFINIÇÃO DE KEY POR MAIORIA
% =========================================================

impacto_max = impacto_ind == scale_max(1);

candidatos_key = find( ...
    sum(impacto_max,2)/nExperts >= 0.5 );
% =========================================================
% ALERTA DE DIVERGÊNCIA ENTRE ESPECIALISTAS
% =========================================================

impacto_max_val = max(impacto_ind, [], 2);
impacto_min_val = min(impacto_ind, [], 2);

alerta_div = (impacto_max_val - impacto_min_val) >= 3;

% classificação S2 (grupo) via K-means
cat = classify_requirements_kmeans(phi_net, candidatos_key);
% Auditoria dos grupos K-means no S2
[idx_km_s2, C_s2, group_names_s2] = get_kmeans_groups(phi_net, candidatos_key);

T_kmeans_s2 = table((1:numel(C_s2))', C_s2(:), group_names_s2(:), ...
    'VariableNames', {'Cluster','Centroide','Grupo'});

disp(' ');
disp('--- CENTRÓIDES K-MEANS (S2) ---');
disp(T_kmeans_s2);

writetable(T_kmeans_s2, 'KMeans_Clusters_S2.xlsx');

%% ---------------------------------------------------------
% 9. TABELA FINAL E EXPORTAÇÃO - S2
% Aba 1: Consolidado
% Aba 2: Dados_Brutos
% ---------------------------------------------------------

arquivo_resultado = ...
    'Resultado_S2_FAHP_FuzzyPromethee_Geldermann.xlsx';

%% =========================================================
% TABELA COMPLETA — DADOS BRUTOS
% =========================================================

T_res = table( ...
    req_labels(:), ...
    IDs(:), ...
    Phi_plus_fuzzy(:,1), ...
    Phi_plus_fuzzy(:,2), ...
    Phi_plus_fuzzy(:,3), ...
    Phi_plus_fuzzy(:,4), ...
    Phi_minus_fuzzy(:,1), ...
    Phi_minus_fuzzy(:,2), ...
    Phi_minus_fuzzy(:,3), ...
    Phi_minus_fuzzy(:,4), ...
    Phi_net_fuzzy(:,1), ...
    Phi_net_fuzzy(:,2), ...
    Phi_net_fuzzy(:,3), ...
    Phi_net_fuzzy(:,4), ...
    Phi_plus(:), ...
    Phi_minus(:), ...
    phi_net(:), ...
    cat(:), ...
    'VariableNames', { ...
        'Req', ...
        'ID', ...
        'PhiPlus_a', ...
        'PhiPlus_b', ...
        'PhiPlus_c', ...
        'PhiPlus_d', ...
        'PhiMinus_a', ...
        'PhiMinus_b', ...
        'PhiMinus_c', ...
        'PhiMinus_d', ...
        'PhiNet_a', ...
        'PhiNet_b', ...
        'PhiNet_c', ...
        'PhiNet_d', ...
        'Phi_Plus', ...
        'Phi_Minus', ...
        'Net_Flow', ...
        'Categoria'});

% Ordena pelo fluxo líquido, do maior para o menor
T_res = sortrows(T_res, 'Net_Flow', 'descend');

% Cria o ranking após a ordenação
T_res.Rank = (1:height(T_res))';

% Move Rank para a primeira coluna
T_res = movevars(T_res, 'Rank', 'Before', 'Req');

%% =========================================================
% TABELA CONSOLIDADA
% =========================================================

T_consolidado = T_res(:, { ...
    'Rank', ...
    'Req', ...
    'Phi_Plus', ...
    'Phi_Minus', ...
    'Net_Flow', ...
    'Categoria'});

% Renomeia as colunas da tabela resumida
T_consolidado.Properties.VariableNames = { ...
    'Rank', ...
    'Requisito', ...
    'Phi_Plus', ...
    'Phi_Minus', ...
    'Phi_Liquido', ...
    'Categoria'};

%% =========================================================
% EXIBIÇÃO NO COMMAND WINDOW
% =========================================================

disp('Top 10 requisitos - Cenário S2:');
disp(head(T_consolidado, min(10,height(T_consolidado))));

%% =========================================================
% EXPORTAÇÃO PARA O MESMO ARQUIVO EXCEL
% =========================================================

% Apaga o arquivo anterior, se ele existir
if isfile(arquivo_resultado)
    try
        delete(arquivo_resultado);
    catch
        error(['Não foi possível substituir o arquivo. ', ...
               'Feche o arquivo no Excel e execute novamente: ', ...
               arquivo_resultado]);
    end
end

% Aba resumida para apresentação
writetable( ...
    T_consolidado, ...
    arquivo_resultado, ...
    'Sheet', 'Consolidado');

% Aba completa para auditoria
writetable( ...
    T_res, ...
    arquivo_resultado, ...
    'Sheet', 'Dados_Brutos');

fprintf('\nArquivo criado com sucesso:\n');
fprintf('%s\n', arquivo_resultado);
fprintf('Aba 1: Consolidado\n');
fprintf('Aba 2: Dados_Brutos\n');



%% =========================================================
% EXPORTAR MATRIZ DE ENTRADA FUZZY (AUDITORIA MÉTRICA)
%% =========================================================
% Criamos uma tabela consolidando os trapézios das notas (F)
F_flat = [];
col_names_F = {};
for k = 1:nCrit
    F_flat = [F_flat, squeeze(F(:,k,:))];
    col_names_F = [col_names_F, ...
        {['val_',crit_names{k},'_a'], ['val_',crit_names{k},'_b'], ...
         ['val_',crit_names{k},'_c'], ['val_',crit_names{k},'_d']}];
end

T_audit = array2table(F_flat, 'VariableNames', col_names_F, 'RowNames', req_labels);
writetable(T_audit, 'Auditoria_Entrada_Fuzzy.xlsx', 'WriteRowNames', true);

%% ---------------------------------------------------------
% 10. TABELA DE COMPARAÇÃO S1 VS S2
% ---------------------------------------------------------
rank_s1 = nReq + 1 - tiedrank(phi_liq_base(:));
rank_s2 = nReq + 1 - tiedrank(phi_net(:));
delta_rank = rank_s1 - rank_s2;

T_compare = table(req_labels(:), phi_liq_base(:), phi_net(:), ...
    rank_s1, rank_s2, delta_rank, ...
    'VariableNames', {'Req','PhiNet_S1','PhiNet_S2','Rank_S1','Rank_S2','DeltaRank'});

disp(T_compare);
writetable(T_compare, 'Comparacao_S1_S2.xlsx');

%% =========================================================
% CORRELAÇÃO DOS FLUXOS LÍQUIDOS
%% =========================================================

phi_all = [phi_net_experts,...
           phi_net(:),...
           phi_liq_base(:)];

labels_phi = [all_sheets(:); ...
              {'GrupoS2'}; ...
              {'S1'}];

rho_phi_spear = corr(phi_all,...
                     'Type','Spearman');

rho_phi_pear = corr(phi_all,...
                    'Type','Pearson');

disp(' ')
disp('--- SPEARMAN DOS FLUXOS LIQUIDOS ---')
disp(array2table(rho_phi_spear,...
    'VariableNames',labels_phi,...
    'RowNames',labels_phi))

disp(' ')
disp('--- PEARSON DOS FLUXOS LIQUIDOS ---')
disp(array2table(rho_phi_pear,...
    'VariableNames',labels_phi,...
    'RowNames',labels_phi))
%% =========================================================
% 10A. CLASSIFICAÇÕES DE TODAS AS FONTES
%% =========================================================

% S1: usa a mesma lógica de KEY do grupo
cat_s1 = classify_requirements_kmeans(phi_liq_base, candidatos_key);

% S2: já foi calculada acima como "cat"
cat_s2 = cat;

% especialistas individuais
cat_exp = strings(nReq, nExperts);

for e = 1:nExperts
    key_e = find(impacto_ind(:,e) == scale_max(1));   % key do próprio especialista
        cat_exp(:,e) = classify_requirements_kmeans(phi_net_experts(:,e), key_e);
end


%% =========================================================
% CONCORDÂNCIA DAS CLASSIFICAÇÕES
% WEIGHTED COHEN'S KAPPA
%
% Ordem das categorias:
%   Key > G1 > G2 > G3
%
% Ponderação quadrática:
%   desacordos distantes recebem penalidade maior
%% =========================================================

% Organização das fontes:
% E1, E2, ..., En, S1 e S2
classes_kappa = [ ...
    cat_exp, ...
    cat_s1(:), ...
    cat_s2(:)];

nFontesKappa = size(classes_kappa,2);

% Rótulos das fontes
labels_kappa = strings(nFontesKappa,1);

for e = 1:nExperts
    labels_kappa(e) = sprintf('E%d',e);
end

labels_kappa(nExperts+1) = "S1";
labels_kappa(nExperts+2) = "S2";

%% ---------------------------------------------------------
% Conversão das categorias em códigos ordinais
%
% Key = 1
% G1  = 2
% G2  = 3
% G3  = 4
%% ---------------------------------------------------------

classes_codigo = zeros(size(classes_kappa));

for j = 1:nFontesKappa
    classes_codigo(:,j) = classToCode(classes_kappa(:,j));
end

%% ---------------------------------------------------------
% Matriz par a par de Weighted Cohen's Kappa
%% ---------------------------------------------------------

kappa_ponderado = nan(nFontesKappa,nFontesKappa);

for a = 1:nFontesKappa

    for b = 1:nFontesKappa

        kappa_ponderado(a,b) = weightedCohenKappa( ...
            classes_codigo(:,a), ...
            classes_codigo(:,b), ...
            4, ...
            'quadratic');

    end
end

%% ---------------------------------------------------------
% Exibição no Command Window
%% ---------------------------------------------------------

nomes_kappa_validos = matlab.lang.makeValidName( ...
    cellstr(labels_kappa));

T_kappa_ponderado = array2table( ...
    kappa_ponderado, ...
    'VariableNames',nomes_kappa_validos, ...
    'RowNames',cellstr(labels_kappa));

disp(' ');
disp('============================================================');
disp('WEIGHTED COHEN''S KAPPA DAS CLASSIFICAÇÕES');
disp('Categorias: Key, G1, G2 e G3');
disp('Ponderação: quadrática');
disp('============================================================');
disp(T_kappa_ponderado);

%% ---------------------------------------------------------
% Exportação da matriz para Excel
%% ---------------------------------------------------------

writetable( ...
    T_kappa_ponderado, ...
    'Concordancia_Classificacoes_Kappa.xlsx', ...
    'Sheet','Kappa_Quadratico', ...
    'WriteRowNames',true);

%% ---------------------------------------------------------
% Heatmap do Weighted Cohen's Kappa
%% ---------------------------------------------------------

fig_kappa = figure( ...
    'Color','w', ...
    'Position',[130 80 900 760], ...
    'Visible','on', ...
    'Name', ...
    'Concordância das classificações - Weighted Cohen Kappa', ...
    'NumberTitle','off');

imagesc(kappa_ponderado);

axis square;
box on;

% O Kappa pode variar de -1 a 1
caxis([-1 1]);

colormap(fig_kappa,parula);

cb = colorbar;
cb.Label.String = 'Weighted Cohen''s Kappa';

title( ...
    {'Concordância das classificações entre especialistas, S1 e S2', ...
     'Weighted Cohen''s Kappa com ponderação quadrática'}, ...
    'FontSize',13, ...
    'FontWeight','bold');

xlabel('Fonte de classificação');
ylabel('Fonte de classificação');

xticks(1:nFontesKappa);
yticks(1:nFontesKappa);

xticklabels(labels_kappa);
yticklabels(labels_kappa);

xtickangle(45);

%% ---------------------------------------------------------
% Valores dentro das células
%% ---------------------------------------------------------

for i = 1:nFontesKappa

    for j = 1:nFontesKappa

        valor = kappa_ponderado(i,j);

        if isnan(valor)

            texto_valor = 'NaN';
            cor_texto = 'k';

        else

            texto_valor = sprintf('%.3f',valor);

            % No parula, valores menores tendem a ser mais escuros
            if valor < 0.15
                cor_texto = 'w';
            else
                cor_texto = 'k';
            end

        end

        text( ...
            j,i, ...
            texto_valor, ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',9, ...
            'FontWeight','bold', ...
            'Color',cor_texto);

    end
end

set(gca, ...
    'TickLength',[0 0], ...
    'FontSize',10, ...
    'Layer','top');

drawnow;

%% =========================================================
% CLASSIFICAÇÃO FINAL PARA STAKEHOLDERS
%% =========================================================

T_final = table(req_labels(:), ...
                IDs, ...
                phi_net(:), ...
                rank_s2(:), ...
                cat(:), ...
                alerta_div(:), ...
    'VariableNames',{'Req','ID','PhiNet','Rank','Categoria','Alerta_Divergencia'});

T_final = sortrows(T_final,'Rank');

disp('CLASSIFICAÇÃO FINAL DOS REQUISITOS')
disp(T_final)

writetable(T_final,'Classificacao_Final_Requisitos.xlsx')
%% =========================================================
% COMPARAÇÃO COMPLETA DOS RANKINGS + CLASSIFICAÇÕES
%% =========================================================

vars = {req_labels(:)};

varNames = {'Req'};

for e = 1:nExperts

    vars{end+1} = rank_matrix(:,e);
    vars{end+1} = cat_exp(:,e);

    varNames{end+1} = sprintf('Rank_E%d',e);
    varNames{end+1} = sprintf('Classe_E%d',e);

end

vars{end+1} = rank_s2(:);
vars{end+1} = cat_s2(:);

varNames{end+1} = 'Rank_S2';
varNames{end+1} = 'Classe_S2';

T_rank_all = table(vars{:},...
                   'VariableNames',varNames);

writetable(T_rank_all,'Comparacao_Todos_Rankings.xlsx')
disp(' ')
disp('--- COMPARAÇÃO COMPLETA DOS RANKINGS + CLASSIFICAÇÕES ---')
disp(T_rank_all)


%% =========================================================
% ANÁLISE DAS DIFERENÇAS DE RANKING E CLASSIFICAÇÃO
%
% Resultados produzidos:
%
% 1. Histograma de |Delta Rank| para cada especialista
% 2. Tabela-resumo das diferenças de ranking
% 3. Boxplot das posições de cada requisito
%
% 4. Histograma de |Delta Classe| para cada especialista
% 5. Tabela-resumo das diferenças de classificação
% 6. Boxplot das classificações de cada requisito
%
% Comparação sempre realizada em relação ao resultado
% consolidado do cenário S2.
%% =========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('ANÁLISE DAS DIFERENÇAS DE RANKING E CLASSIFICAÇÃO\n');
fprintf('============================================================\n');

%% ---------------------------------------------------------
% 1. NOMES DOS ESPECIALISTAS
%% ---------------------------------------------------------

nomes_especialistas = strings(nExperts,1);

for e = 1:nExperts

    % Usa o nome da aba como identificação do especialista
    nomes_especialistas(e) = string(all_sheets{e});

    % Alternativa:
    % nomes_especialistas(e) = sprintf('E%d',e);

end

%% =========================================================
% PARTE A — ANÁLISE DOS RANKINGS
%% =========================================================

%% ---------------------------------------------------------
% 2. DIFERENÇA ENTRE O RANKING INDIVIDUAL E O RANKING S2
%
% Delta com sinal:
%
%   Delta > 0:
%   o especialista colocou o requisito em posição numericamente
%   maior, ou seja, mais abaixo que o grupo.
%
%   Delta < 0:
%   o especialista colocou o requisito em posição numericamente
%   menor, ou seja, mais acima que o grupo.
%
% Para a análise de aderência é utilizado |Delta Rank|.
%% ---------------------------------------------------------

delta_rank_exp = zeros(nReq,nExperts);
abs_delta_rank_exp = zeros(nReq,nExperts);

for e = 1:nExperts

    delta_rank_exp(:,e) = ...
        rank_matrix(:,e) - rank_s2(:);

    abs_delta_rank_exp(:,e) = ...
        abs(delta_rank_exp(:,e));

end

%% ---------------------------------------------------------
% 3. HISTOGRAMA DE |DELTA RANK| PARA CADA ESPECIALISTA
%% ---------------------------------------------------------

nColunas = min(3,nExperts);
nLinhas = ceil(nExperts/nColunas);

fig_hist_rank = figure( ...
    'Color','w', ...
    'Position',[80 60 430*nColunas 320*nLinhas], ...
    'Visible','on', ...
    'Name','Histogramas das diferenças absolutas de ranking', ...
    'NumberTitle','off');

tiledlayout( ...
    nLinhas, ...
    nColunas, ...
    'TileSpacing','compact', ...
    'Padding','compact');

% Limite comum do eixo X
max_delta_rank = max(abs_delta_rank_exp,[],'all');

% Garante pelo menos uma unidade no eixo
max_delta_rank = max(1,ceil(max_delta_rank));

for e = 1:nExperts

    nexttile;

    histogram( ...
        abs_delta_rank_exp(:,e), ...
        'BinEdges',-0.5:1:(max_delta_rank+0.5), ...
        'FaceAlpha',0.80);

    title( ...
        sprintf('%s versus Grupo S2',nomes_especialistas(e)), ...
        'Interpreter','none', ...
        'FontWeight','bold');

    xlabel('|\Delta Rank|');
    ylabel('Número de requisitos');

    xticks(0:max_delta_rank);
    xlim([-0.5 max_delta_rank+0.5]);

    grid on;
    box on;

    % Linha com a média das diferenças absolutas
    media_e = mean(abs_delta_rank_exp(:,e));

    xline( ...
        media_e, ...
        '--', ...
        sprintf('Média = %.2f',media_e), ...
        'LabelVerticalAlignment','middle', ...
        'LabelHorizontalAlignment','left', ...
        'LineWidth',1.4);

end

sgtitle( ...
    {'Diferença absoluta entre os rankings individuais e o ranking consolidado', ...
     'Valores menores indicam maior aderência ao resultado do grupo'}, ...
    'FontSize',14, ...
    'FontWeight','bold');

drawnow;

exportgraphics( ...
    fig_hist_rank, ...
    fullfile(pasta_figuras, ...
    'Histogramas_Diferencas_Absolutas_Ranking.png'), ...
    'Resolution',300);

%% ---------------------------------------------------------
% 4. TABELA-RESUMO DAS DIFERENÇAS DE RANKING
%% ---------------------------------------------------------

rank_media   = zeros(nExperts,1);
rank_mediana = zeros(nExperts,1);
rank_desvio  = zeros(nExperts,1);
rank_maximo  = zeros(nExperts,1);

% Indicadores adicionais de fácil interpretação
rank_igual       = zeros(nExperts,1);
rank_ate_1       = zeros(nExperts,1);
rank_ate_2       = zeros(nExperts,1);
rank_ate_3       = zeros(nExperts,1);
rank_ate_5       = zeros(nExperts,1);

for e = 1:nExperts

    valores = abs_delta_rank_exp(:,e);

    rank_media(e)   = mean(valores);
    rank_mediana(e) = median(valores);
    rank_desvio(e)  = std(valores,0);
    rank_maximo(e)  = max(valores);

    % Percentuais de requisitos dentro de cada tolerância
    rank_igual(e) = 100*mean(valores == 0);
    rank_ate_1(e) = 100*mean(valores <= 1);
    rank_ate_2(e) = 100*mean(valores <= 2);
    rank_ate_3(e) = 100*mean(valores <= 3);
    rank_ate_5(e) = 100*mean(valores <= 5);

end

T_resumo_rank = table( ...
    nomes_especialistas, ...
    rank_media, ...
    rank_mediana, ...
    rank_desvio, ...
    rank_maximo, ...
    rank_igual, ...
    rank_ate_1, ...
    rank_ate_2, ...
    rank_ate_3, ...
    rank_ate_5, ...
    'VariableNames',{ ...
        'Especialista', ...
        'Media_AbsDeltaRank', ...
        'Mediana_AbsDeltaRank', ...
        'DesvioPadrao_AbsDeltaRank', ...
        'Maximo_AbsDeltaRank', ...
        'Percentual_DeltaZero', ...
        'Percentual_DeltaAte1', ...
        'Percentual_DeltaAte2', ...
        'Percentual_DeltaAte3', ...
        'Percentual_DeltaAte5'});

% Ordena do especialista mais próximo ao mais distante do grupo
T_resumo_rank = sortrows( ...
    T_resumo_rank, ...
    'Media_AbsDeltaRank', ...
    'ascend');

disp(' ');
disp('--- RESUMO DAS DIFERENÇAS DE RANKING ---');
disp(T_resumo_rank);

%% ---------------------------------------------------------
% 5. TABELA DETALHADA DAS DIFERENÇAS DE RANKING
%% ---------------------------------------------------------

vars_rank_detalhe = {req_labels(:), rank_s2(:)};
nomes_rank_detalhe = {'Requisito','Rank_S2'};

for e = 1:nExperts

    vars_rank_detalhe{end+1} = rank_matrix(:,e);
    vars_rank_detalhe{end+1} = delta_rank_exp(:,e);
    vars_rank_detalhe{end+1} = abs_delta_rank_exp(:,e);

    nomes_rank_detalhe{end+1} = sprintf('Rank_E%d',e);
    nomes_rank_detalhe{end+1} = sprintf('DeltaRank_E%d',e);
    nomes_rank_detalhe{end+1} = sprintf('AbsDeltaRank_E%d',e);

end

T_detalhe_rank = table( ...
    vars_rank_detalhe{:}, ...
    'VariableNames',nomes_rank_detalhe);

T_detalhe_rank = sortrows(T_detalhe_rank,'Rank_S2');

%% ---------------------------------------------------------
% 6. BOXPLOT DAS POSIÇÕES DE CADA REQUISITO
%
% Cada caixa contém as posições atribuídas pelos especialistas.
% O losango representa a posição consolidada no Grupo S2.
%% ---------------------------------------------------------

fig_box_rank = figure( ...
    'Color','w', ...
    'Position',[80 80 1450 650], ...
    'Visible','on', ...
    'Name','Boxplot das posições dos requisitos', ...
    'NumberTitle','off');

% A matriz é transposta:
% linhas = especialistas
% colunas = requisitos
boxplot( ...
    rank_matrix(:,1:nExperts)', ...
    'Labels',req_labels, ...
    'Symbol','o');

hold on;

% Posição consolidada do requisito no ranking S2
scatter( ...
    1:nReq, ...
    rank_s2(:), ...
    60, ...
    'd', ...
    'filled', ...
    'DisplayName','Ranking consolidado S2');

% Posição 1 deve aparecer no topo
set(gca,'YDir','reverse');

ylim([0.5 nReq+0.5]);
yticks(1:nReq);

xlabel('Requisitos');
ylabel('Posição no ranking');

title( ...
    {'Dispersão das posições atribuídas aos requisitos', ...
     'Caixas: especialistas individuais | Losango: ranking consolidado S2'}, ...
    'FontSize',13, ...
    'FontWeight','bold');

xtickangle(90);
grid on;
box on;

legend( ...
    'Ranking consolidado S2', ...
    'Location','eastoutside');

hold off;
drawnow;

exportgraphics( ...
    fig_box_rank, ...
    fullfile(pasta_figuras, ...
    'Boxplot_Posicoes_Ranking_Requisitos.png'), ...
    'Resolution',300);

%% ---------------------------------------------------------
% 7. CONTROVÉRSIA DOS REQUISITOS COM BASE NO RANKING
%% ---------------------------------------------------------

rank_req_media   = mean(rank_matrix(:,1:nExperts),2);
rank_req_mediana = median(rank_matrix(:,1:nExperts),2);
rank_req_std     = std(rank_matrix(:,1:nExperts),0,2);

rank_req_min = min( ...
    rank_matrix(:,1:nExperts), ...
    [],2);

rank_req_max = max( ...
    rank_matrix(:,1:nExperts), ...
    [],2);

rank_req_amplitude = rank_req_max-rank_req_min;

% MAD manual para evitar dependência de toolbox específico
rank_req_mad = zeros(nReq,1);

for i = 1:nReq

    valores = rank_matrix(i,1:nExperts);

    rank_req_mad(i) = median( ...
        abs(valores-median(valores)));

end

T_controversia_rank = table( ...
    req_labels(:), ...
    rank_s2(:), ...
    rank_req_media, ...
    rank_req_mediana, ...
    rank_req_std, ...
    rank_req_mad, ...
    rank_req_min, ...
    rank_req_max, ...
    rank_req_amplitude, ...
    'VariableNames',{ ...
        'Requisito', ...
        'Rank_S2', ...
        'Media_Posicao', ...
        'Mediana_Posicao', ...
        'DesvioPadrao_Posicao', ...
        'MAD_Posicao', ...
        'Melhor_Posicao', ...
        'Pior_Posicao', ...
        'Amplitude_Posicao'});

% Requisitos com maior dispersão aparecem primeiro
T_controversia_rank = sortrows( ...
    T_controversia_rank, ...
    {'DesvioPadrao_Posicao','Amplitude_Posicao'}, ...
    {'descend','descend'});

disp(' ');
disp('--- REQUISITOS MAIS CONTROVERSOS PELO RANKING ---');
disp(head(T_controversia_rank,min(15,height(T_controversia_rank))));

%% =========================================================
% PARTE B — ANÁLISE DAS CLASSIFICAÇÕES
%% =========================================================

%% ---------------------------------------------------------
% 8. CONVERSÃO DAS CLASSIFICAÇÕES PARA CÓDIGOS ORDINAIS
%
% A função classToCode já existente deve produzir:
%
% Key = 1
% G1  = 2
% G2  = 3
% G3  = 4
%% ---------------------------------------------------------

classe_codigo_exp = zeros(nReq,nExperts);

for e = 1:nExperts

    classe_codigo_exp(:,e) = ...
        classToCode(cat_exp(:,e));

end

classe_codigo_s2 = classToCode(cat_s2(:));

%% ---------------------------------------------------------
% 9. DIFERENÇAS DE CLASSIFICAÇÃO
%
% |Delta Classe| = 0:
% mesma classificação.
%
% |Delta Classe| = 1:
% diferença de uma categoria.
%
% |Delta Classe| = 2:
% diferença de duas categorias.
%
% |Delta Classe| = 3:
% diferença máxima, por exemplo Key versus G3.
%% ---------------------------------------------------------

delta_classe_exp = zeros(nReq,nExperts);
abs_delta_classe_exp = zeros(nReq,nExperts);

for e = 1:nExperts

    delta_classe_exp(:,e) = ...
        classe_codigo_exp(:,e)-classe_codigo_s2;

    abs_delta_classe_exp(:,e) = ...
        abs(delta_classe_exp(:,e));

end

%% ---------------------------------------------------------
% 10. HISTOGRAMA DE |DELTA CLASSE| PARA CADA ESPECIALISTA
%% ---------------------------------------------------------

fig_hist_classe = figure( ...
    'Color','w', ...
    'Position',[80 60 430*nColunas 320*nLinhas], ...
    'Visible','on', ...
    'Name','Histogramas das diferenças de classificação', ...
    'NumberTitle','off');

tiledlayout( ...
    nLinhas, ...
    nColunas, ...
    'TileSpacing','compact', ...
    'Padding','compact');

for e = 1:nExperts

    nexttile;

    histogram( ...
        abs_delta_classe_exp(:,e), ...
        'BinEdges',-0.5:1:3.5, ...
        'FaceAlpha',0.80);

    title( ...
        sprintf('%s versus Grupo S2',nomes_especialistas(e)), ...
        'Interpreter','none', ...
        'FontWeight','bold');

    xlabel('|\Delta Classe|');
    ylabel('Número de requisitos');

    xticks(0:3);
    xticklabels({ ...
        '0: igual', ...
        '1 categoria', ...
        '2 categorias', ...
        '3 categorias'});

    xtickangle(20);
    xlim([-0.5 3.5]);

    grid on;
    box on;

    media_e = mean(abs_delta_classe_exp(:,e));

    xline( ...
        media_e, ...
        '--', ...
        sprintf('Média = %.2f',media_e), ...
        'LabelVerticalAlignment','middle', ...
        'LabelHorizontalAlignment','left', ...
        'LineWidth',1.4);

end

sgtitle( ...
    {'Diferença absoluta entre as classificações individuais e a classificação consolidada', ...
     'Categorias ordinais: Key, G1, G2 e G3'}, ...
    'FontSize',14, ...
    'FontWeight','bold');

drawnow;

exportgraphics( ...
    fig_hist_classe, ...
    fullfile(pasta_figuras, ...
    'Histogramas_Diferencas_Absolutas_Classificacao.png'), ...
    'Resolution',300);

%% ---------------------------------------------------------
% 11. TABELA-RESUMO DAS DIFERENÇAS DE CLASSIFICAÇÃO
%% ---------------------------------------------------------

classe_media   = zeros(nExperts,1);
classe_mediana = zeros(nExperts,1);
classe_desvio  = zeros(nExperts,1);
classe_maximo  = zeros(nExperts,1);

classe_igual = zeros(nExperts,1);
classe_ate_1 = zeros(nExperts,1);
classe_mais_1 = zeros(nExperts,1);

for e = 1:nExperts

    valores = abs_delta_classe_exp(:,e);

    classe_media(e)   = mean(valores);
    classe_mediana(e) = median(valores);
    classe_desvio(e)  = std(valores,0);
    classe_maximo(e)  = max(valores);

    classe_igual(e) = 100*mean(valores == 0);
    classe_ate_1(e) = 100*mean(valores <= 1);
    classe_mais_1(e) = 100*mean(valores > 1);

end

T_resumo_classe = table( ...
    nomes_especialistas, ...
    classe_media, ...
    classe_mediana, ...
    classe_desvio, ...
    classe_maximo, ...
    classe_igual, ...
    classe_ate_1, ...
    classe_mais_1, ...
    'VariableNames',{ ...
        'Especialista', ...
        'Media_AbsDeltaClasse', ...
        'Mediana_AbsDeltaClasse', ...
        'DesvioPadrao_AbsDeltaClasse', ...
        'Maximo_AbsDeltaClasse', ...
        'Percentual_MesmaClasse', ...
        'Percentual_DiferencaAte1Classe', ...
        'Percentual_DiferencaMaiorQue1Classe'});

T_resumo_classe = sortrows( ...
    T_resumo_classe, ...
    'Media_AbsDeltaClasse', ...
    'ascend');

disp(' ');
disp('--- RESUMO DAS DIFERENÇAS DE CLASSIFICAÇÃO ---');
disp(T_resumo_classe);

%% ---------------------------------------------------------
% 12. TABELA DETALHADA DAS DIFERENÇAS DE CLASSIFICAÇÃO
%% ---------------------------------------------------------

vars_classe_detalhe = { ...
    req_labels(:), ...
    cat_s2(:), ...
    classe_codigo_s2};

nomes_classe_detalhe = { ...
    'Requisito', ...
    'Classe_S2', ...
    'CodigoClasse_S2'};

for e = 1:nExperts

    vars_classe_detalhe{end+1} = cat_exp(:,e);
    vars_classe_detalhe{end+1} = classe_codigo_exp(:,e);
    vars_classe_detalhe{end+1} = delta_classe_exp(:,e);
    vars_classe_detalhe{end+1} = abs_delta_classe_exp(:,e);

    nomes_classe_detalhe{end+1} = sprintf('Classe_E%d',e);
    nomes_classe_detalhe{end+1} = sprintf('CodigoClasse_E%d',e);
    nomes_classe_detalhe{end+1} = sprintf('DeltaClasse_E%d',e);
    nomes_classe_detalhe{end+1} = sprintf('AbsDeltaClasse_E%d',e);

end

T_detalhe_classe = table( ...
    vars_classe_detalhe{:}, ...
    'VariableNames',nomes_classe_detalhe);

%% ---------------------------------------------------------
% 13. BOXPLOT DAS CLASSIFICAÇÕES POR REQUISITO
%
% O boxplot é aplicado aos códigos ordinais:
%
% 1 = Key
% 2 = G1
% 3 = G2
% 4 = G3
%
% O losango mostra a classificação consolidada S2.
%% ---------------------------------------------------------

fig_box_classe = figure( ...
    'Color','w', ...
    'Position',[80 80 1450 620], ...
    'Visible','on', ...
    'Name','Boxplot das classificações dos requisitos', ...
    'NumberTitle','off');

boxplot( ...
    classe_codigo_exp', ...
    'Labels',req_labels, ...
    'Symbol','o');

hold on;

scatter( ...
    1:nReq, ...
    classe_codigo_s2, ...
    60, ...
    'd', ...
    'filled', ...
    'DisplayName','Classificação consolidada S2');

% Key aparece no topo e G3 na parte inferior
set(gca,'YDir','reverse');

ylim([0.5 4.5]);
yticks(1:4);
yticklabels({'Key','G1','G2','G3'});

xlabel('Requisitos');
ylabel('Classificação');

title( ...
    {'Dispersão das classificações atribuídas aos requisitos', ...
     'Caixas: especialistas individuais | Losango: classificação consolidada S2'}, ...
    'FontSize',13, ...
    'FontWeight','bold');

xtickangle(90);
grid on;
box on;

legend( ...
    'Classificação consolidada S2', ...
    'Location','eastoutside');

hold off;
drawnow;

exportgraphics( ...
    fig_box_classe, ...
    fullfile(pasta_figuras, ...
    'Boxplot_Classificacoes_Requisitos.png'), ...
    'Resolution',300);

%% ---------------------------------------------------------
% 14. CONTROVÉRSIA DOS REQUISITOS PELA CLASSIFICAÇÃO
%% ---------------------------------------------------------

classe_req_media = mean(classe_codigo_exp,2);
classe_req_mediana = median(classe_codigo_exp,2);
classe_req_std = std(classe_codigo_exp,0,2);

classe_req_min = min(classe_codigo_exp,[],2);
classe_req_max = max(classe_codigo_exp,[],2);
classe_req_amplitude = classe_req_max-classe_req_min;

classe_req_mad = zeros(nReq,1);

for i = 1:nReq

    valores = classe_codigo_exp(i,:);

    classe_req_mad(i) = median( ...
        abs(valores-median(valores)));

end

% Percentual de especialistas que concordam exatamente com S2
percentual_acordo_classe = zeros(nReq,1);

for i = 1:nReq

    percentual_acordo_classe(i) = ...
        100*mean( ...
        classe_codigo_exp(i,:) == classe_codigo_s2(i));

end

T_controversia_classe = table( ...
    req_labels(:), ...
    cat_s2(:), ...
    classe_codigo_s2, ...
    classe_req_media, ...
    classe_req_mediana, ...
    classe_req_std, ...
    classe_req_mad, ...
    classe_req_min, ...
    classe_req_max, ...
    classe_req_amplitude, ...
    percentual_acordo_classe, ...
    'VariableNames',{ ...
        'Requisito', ...
        'Classe_S2', ...
        'CodigoClasse_S2', ...
        'Media_CodigoClasse', ...
        'Mediana_CodigoClasse', ...
        'DesvioPadrao_Classe', ...
        'MAD_Classe', ...
        'Melhor_Classe_Codigo', ...
        'Pior_Classe_Codigo', ...
        'Amplitude_Classe', ...
        'Percentual_AcordoComS2'});

T_controversia_classe = sortrows( ...
    T_controversia_classe, ...
    {'DesvioPadrao_Classe', ...
     'Amplitude_Classe', ...
     'Percentual_AcordoComS2'}, ...
    {'descend','descend','ascend'});

disp(' ');
disp('--- REQUISITOS MAIS CONTROVERSOS PELA CLASSIFICAÇÃO ---');
disp(head( ...
    T_controversia_classe, ...
    min(15,height(T_controversia_classe))));

%% =========================================================
% 15. EXPORTAÇÃO PARA EXCEL
%% =========================================================

arquivo_analise_diferencas = ...
    'Analise_Diferencas_Ranking_Classificacao.xlsx';

if isfile(arquivo_analise_diferencas)

    try
        delete(arquivo_analise_diferencas);

    catch

        error([ ...
            'Não foi possível substituir o arquivo. ', ...
            'Feche o arquivo no Excel e execute novamente: ', ...
            arquivo_analise_diferencas]);

    end

end

writetable( ...
    T_resumo_rank, ...
    arquivo_analise_diferencas, ...
    'Sheet','Resumo_Ranking');

writetable( ...
    T_detalhe_rank, ...
    arquivo_analise_diferencas, ...
    'Sheet','Detalhes_Ranking');

writetable( ...
    T_controversia_rank, ...
    arquivo_analise_diferencas, ...
    'Sheet','Controversia_Ranking');

writetable( ...
    T_resumo_classe, ...
    arquivo_analise_diferencas, ...
    'Sheet','Resumo_Classificacao');

writetable( ...
    T_detalhe_classe, ...
    arquivo_analise_diferencas, ...
    'Sheet','Detalhes_Classificacao');

writetable( ...
    T_controversia_classe, ...
    arquivo_analise_diferencas, ...
    'Sheet','Controversia_Classificacao');

fprintf('\n');
fprintf('Análise concluída com sucesso.\n');
fprintf('Arquivo criado: %s\n',arquivo_analise_diferencas);
fprintf('\nAbas criadas:\n');
fprintf('1. Resumo_Ranking\n');
fprintf('2. Detalhes_Ranking\n');
fprintf('3. Controversia_Ranking\n');
fprintf('4. Resumo_Classificacao\n');
fprintf('5. Detalhes_Classificacao\n');
fprintf('6. Controversia_Classificacao\n');
fprintf('\n');


%% =========================================================
% 11. RESUMO ANALÍTICO
%% =========================================================
disp(' ');
disp('============================================================');
disp('RESUMO ANALÍTICO DOS RESULTADOS MAIS RELEVANTES');
disp('============================================================');

disp(' ');
disp('--- PESOS DOS CRITÉRIOS ---');
T_pesos = table(crit_names(:), ...
    w_s1_fuzzy(:,1), w_s1_fuzzy(:,2), w_s1_fuzzy(:,3), w_s1_fuzzy(:,4), ...
    w_fuzzy_group(:,1), w_fuzzy_group(:,2), w_fuzzy_group(:,3), w_fuzzy_group(:,4), ...
    w_group_defuzz(:), ...
    'VariableNames', {'Criterio', ...
                      'wS1_a','wS1_b','wS1_c','wS1_d', ...
                      'wS2_a','wS2_b','wS2_c','wS2_d', ...
                      'wS2_defuzz'});
disp(T_pesos);

rho_s1_s2 = corr(rank_s1, rank_s2, 'Type', 'Spearman');
fprintf('\nSpearman entre ranking S1 e S2 = %.4f\n', rho_s1_s2);

rho_expert_group = zeros(nExperts,1);
for e = 1:nExperts
    rho_expert_group(e) = corr(rank_matrix(:,e), rank_matrix(:,end), 'Type', 'Spearman');
    fprintf('Spearman entre %s e Grupo S2 = %.4f\n', all_sheets{e}, rho_expert_group(e));
end

rho_experts = nan(nExperts, nExperts);
for e1 = 1:nExperts
    for e2 = 1:nExperts
        rho_experts(e1,e2) = corr(rank_matrix(:,e1), rank_matrix(:,e2), 'Type', 'Spearman');
    end
end

disp(' ');
disp('Matriz de Spearman entre especialistas:');
disp(array2table(rho_experts, 'VariableNames', matlab.lang.makeValidName(all_sheets), ...
    'RowNames', matlab.lang.makeValidName(all_sheets)));

[~, idx_s1] = sort(phi_liq_base, 'descend');
[~, idx_s2] = sort(phi_net, 'descend');

Top10_S1 = table(req_labels(idx_s1(1:min(10,nReq)))', phi_liq_base(idx_s1(1:min(10,nReq))), rank_s1(idx_s1(1:min(10,nReq))), ...
    'VariableNames', {'Req','PhiNet_S1','Rank_S1'});

Top10_S2 = table(req_labels(idx_s2(1:min(10,nReq)))', phi_net(idx_s2(1:min(10,nReq))), rank_s2(idx_s2(1:min(10,nReq))), ...
    'VariableNames', {'Req','PhiNet_S2','Rank_S2'});

disp(' ');
disp('--- TOP 10 S1 ---');
disp(Top10_S1);

disp(' ');
disp('--- TOP 10 S2 ---');
disp(Top10_S2);

[~, idx_delta] = sort(abs(delta_rank), 'descend');
T_delta = table(req_labels(:), rank_s1, rank_s2, delta_rank, abs(delta_rank), ...
    'VariableNames', {'Req','Rank_S1','Rank_S2','Delta','AbsDelta'});
T_delta = T_delta(idx_delta,:);

disp(' ');
disp('--- REQUISITOS QUE MAIS MUDARAM DE POSIÇÃO ---');
disp(head(T_delta, min(10,height(T_delta))));

%% =========================================================
% REQUISITOS MAIS CONTROVERSOS
%% =========================================================

T_controv = table(req_labels(:), IDs, ...
    impacto_std, impacto_range, ...
    disp_std_media_req, disp_range_media_req, ...
    phi_net(:), rank_s2(:), cat(:), ...
    'VariableNames', {'Req','ID', ...
                      'Impacto_STD','Impacto_Range', ...
                      'DispMedia_STD','DispMedia_Range', ...
                      'PhiNet','Rank_S2','Categoria'});

% Ordenação principal: maior dispersão global média
T_controv = sortrows(T_controv, {'DispMedia_STD','Impacto_Range'}, {'descend','descend'});

disp(' ');
disp('--- REQUISITOS MAIS CONTROVERSOS (por dispersão média das avaliações) ---');
disp(head(T_controv, min(15,height(T_controv))));

writetable(T_controv, 'Requisitos_Mais_Controversos.xlsx');
%% =========================================================
% OUTLIERS INDIVIDUAIS POR REQUISITO E CRITÉRIO
%% =========================================================

out_req  = {};
out_crit = {};
out_exp  = {};

out_val  = [];
out_med  = [];
out_diff = [];

limiar_outlier = 3;   % diferença mínima na escala

for i = 1:nReq

    for k = 1:nCrit

        vals = squeeze(data_all(i,k,:));

        med_val = median(vals);

        for e = 1:nExperts

            diff_val = abs(vals(e) - med_val);

            if diff_val >= limiar_outlier

                out_req{end+1,1}  = req_labels{i};
                out_crit{end+1,1} = crit_names{k};
                out_exp{end+1,1}  = sprintf('E%d',e);

                out_val(end+1,1)  = vals(e);
                out_med(end+1,1)  = med_val;
                out_diff(end+1,1) = diff_val;

            end

        end

    end

end

T_outliers = table( ...
    out_req,...
    out_crit,...
    out_exp,...
    out_val,...
    out_med,...
    out_diff,...
    'VariableNames', ...
    {'Req','Criterio','Especialista',...
     'Valor','Mediana','Desvio'});

T_outliers = sortrows(T_outliers,...
                      'Desvio',...
                      'descend');

disp(' ')
disp('--- OUTLIERS INDIVIDUAIS ---')
disp(T_outliers)

writetable(T_outliers,...
          'Outliers_Individuais.xlsx');

%% =========================================================
% CONSISTÊNCIA DOS ESPECIALISTAS
%% =========================================================

mean_abs_dev = zeros(nExperts,1);
max_abs_dev  = zeros(nExperts,1);

for e = 1:nExperts

    diffs = [];

    for i = 1:nReq

        for k = 1:nCrit

            vals = squeeze(data_all(i,k,:));

            med_val = median(vals);

            diffs(end+1) = abs(vals(e)-med_val);

        end

    end

    mean_abs_dev(e) = mean(diffs);
    max_abs_dev(e)  = max(diffs);

end

Expert = strings(nExperts,1);

for e = 1:nExperts
    Expert(e) = sprintf('E%d',e);
end

T_consenso = table( ...
    Expert,...
    mean_abs_dev,...
    max_abs_dev,...
    'VariableNames',...
    {'Especialista',...
     'DesvioMedio',...
     'DesvioMaximo'});

T_consenso = sortrows(T_consenso,...
                     'DesvioMedio',...
                     'ascend');

disp(' ')
disp('--- CONSISTÊNCIA DOS ESPECIALISTAS ---')
disp(T_consenso)

writetable(T_consenso,...
          'Consistencia_Especialistas.xlsx');

%% =========================================================
% 12. FIGURA 1 - HEATMAP DE POSIÇÕES
%% =========================================================
fig_posicoes = figure( ...
    'Color','w', ...
    'Position',[100 80 900 720], ...
    'Visible','on', ...
    'Name','Heatmap das posições no ranking', ...
    'NumberTitle','off');
imagesc(rank_matrix_ord);
colormap(flipud(parula));
colorbar;
caxis([1 nReq]);

title('Heatmap das posições no ranking: especialistas vs grupo S2', ...
    'FontSize', 13, 'FontWeight', 'bold');

xticks(1:(nExperts+1));
xticklabels(col_names);
yticks(1:nReq);
yticklabels(req_labels_ord);

xlabel('Fonte de avaliação');
ylabel('Requisitos');

for i = 1:nReq
    for j = 1:(nExperts+1)
        text(j, i, num2str(rank_matrix_ord(i,j)), ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', 'k');
    end
end

set(gca, 'TickLength', [0 0]);
box on;
drawnow;

%% =========================================================
% 13. FIGURA 2 - PESOS FUZZY DOS CRITÉRIOS
%% =========================================================
figure('Color','w','Position',[110 100 950 500]);
hold on;

x = 1:nCrit;
bar(x, w_group_defuzz, 0.55, ...
    'FaceColor', [0.75 0.85 0.95], ...
    'EdgeColor', 'k');

for k = 1:nCrit
    wf = w_fuzzy_group(k,:);

    plot([k k], [wf(1) wf(4)], '-', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
    plot([k k], [wf(2) wf(3)], '-', 'Color', 'k', 'LineWidth', 5);

    plot(k, wf(1), 'o', 'MarkerFaceColor', [0.6 0.6 0.6], 'MarkerEdgeColor', 'k', 'MarkerSize', 5);
    plot(k, wf(4), 'o', 'MarkerFaceColor', [0.6 0.6 0.6], 'MarkerEdgeColor', 'k', 'MarkerSize', 5);
end

set(gca, 'XTick', x, 'XTickLabel', crit_names, 'FontSize', 11);
xtickangle(20);
ylabel('Peso');
title('Pesos fuzzy dos critérios (referência FAHP de grupo)', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
box on;
hold off;

%% =========================================================
% 14. FIGURA 3 - COMPARAÇÃO DO NET FLOW ENTRE S1 E S2
%% =========================================================
figure('Color','w','Position',[120 120 1150 520]);
phi_compare = [phi_liq_base(:), phi_net(:)];
bar(phi_compare, 'grouped');

title('Comparação do fluxo líquido entre S1 e S2', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requisitos');
ylabel('\phi_{net}');
legend({'S1 - FAHP institucional', 'S2 - agregação posterior'}, 'Location', 'best');
set(gca, 'XTick', 1:nReq, 'XTickLabel', req_labels);
xtickangle(90);
grid on;
box on;

%% =========================================================
% 15. FIGURA 4 - SCATTER S1 VS S2
%% =========================================================
figure('Color','w','Position',[130 130 700 620]);
scatter(phi_liq_base, phi_net, 70, 'filled');
hold on;

minv = min([phi_liq_base(:); phi_net(:)]);
maxv = max([phi_liq_base(:); phi_net(:)]);
plot([minv maxv], [minv maxv], '--k', 'LineWidth', 1.5);

for i = 1:nReq
    text(phi_liq_base(i), phi_net(i), [' ' req_labels{i}], ...
        'FontSize', 9, 'FontWeight', 'bold');
end

xlabel('\phi_{net} - S1');
ylabel('\phi_{net} - S2');
title('Comparação entre os fluxos líquidos de S1 e S2', 'FontSize', 13, 'FontWeight', 'bold');
grid on;
box on;
axis equal;
hold off;

rho_s1s2 = corr(phi_liq_base(:), phi_net(:), 'Type', 'Spearman');
fprintf('Spearman entre phi_net de S1 e S2 = %.4f\n', rho_s1s2);

% %% =========================================================
% % 16. FIGURA 5 - SLOPE GRAPH
% %% =========================================================
% figure('Color','w','Position',[140 70 1000 850]);
% hold on;
% colors = lines(nReq);
% x_coords = 1:(nExperts + 1);
% 
% for i = 1:nReq
%     plot(x_coords, rank_matrix(i,:), '-', 'LineWidth', 1.2, 'Color', [0.75 0.75 0.75 0.5]);
% 
%     for j = 1:(nExperts + 1)
%         plot(x_coords(j), rank_matrix(i,j), 'o', ...
%             'MarkerSize', 8, ...
%             'MarkerFaceColor', colors(i,:), ...
%             'MarkerEdgeColor', 'w', ...
%             'LineWidth', 1);
% 
%         if j == 1
%             text(x_coords(j)-0.12, rank_matrix(i,j), req_labels{i}, ...
%                 'HorizontalAlignment', 'right', ...
%                 'FontSize', 8, 'FontWeight', 'bold', 'Color', colors(i,:));
%         elseif j == (nExperts + 1)
%             text(x_coords(j)+0.12, rank_matrix(i,j), req_labels{i}, ...
%                 'HorizontalAlignment', 'left', ...
%                 'FontSize', 8, 'FontWeight', 'bold', 'Color', colors(i,:));
%         end
%     end
% end
% 
% for j = 1:(nExperts + 1)
%     line([j j], [1 nReq], 'Color', [0.85 0.85 0.85], 'LineStyle', ':', 'LineWidth', 1);
%     text(j, 0.2, col_names{j}, ...
%         'HorizontalAlignment', 'center', ...
%         'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none');
% end
% 
% rho_val = corr(rank_matrix(:,end), rank_matrix(:,1), 'type', 'Spearman');
% xlabel_text = sprintf('Exemplo de correlação de Spearman (Grupo S2 vs %s): \\rho = %.4f', ...
%     all_sheets{1}, rho_val);
% 
% text(mean(x_coords), nReq + 1.2, xlabel_text, ...
%     'HorizontalAlignment', 'center', ...
%     'FontSize', 12, ...
%     'FontAngle', 'italic');
% 
% set(gca, 'YDir', 'reverse', 'XColor', 'none', 'YColor', 'none', 'Box', 'off');
% title('Sensibilidade de ranking: especialistas individuais vs grupo S2', 'FontSize', 14, 'FontWeight', 'bold');
% ylim([0, nReq + 1.5]);
% xlim([0.2, nExperts + 1.8]);
% hold off;



%% =========================================================
% 18. FIGURA-RESUMO 3: REQUISITOS QUE MAIS MUDARAM
%% =========================================================
topN = min(15, nReq);
T_delta_plot = T_delta(1:topN,:);

figure('Color','w','Position',[120 120 950 500]);
bar(categorical(T_delta_plot.Req), T_delta_plot.AbsDelta);
title('Requisitos com maior variação de posição entre S1 e S2', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requisitos');
ylabel('|Δ rank|');
grid on;

box on;
%% =========================================================
% HEATMAPS DE CONCORDÂNCIA ENTRE ESPECIALISTAS, S1 E S2
%
% Medidas:
%   1) Spearman Footrule normalizada
%   2) Kendall Tau-b
%
% Fontes comparadas:
%   E1, E2, ..., En, S1 e S2
%% =========================================================

fprintf('\n');
fprintf('============================================================\n');
fprintf('CONCORDÂNCIA ENTRE ESPECIALISTAS, S1 E S2\n');
fprintf('============================================================\n');

%% ---------------------------------------------------------
% 1. MATRIZ COM TODOS OS RANKINGS
%% ---------------------------------------------------------

% rank_matrix(:,1:nExperts) = rankings individuais
% rank_s1                   = ranking do cenário S1
% rank_s2                   = ranking coletivo do cenário S2

rankings_concordancia = [ ...
    rank_matrix(:,1:nExperts), ...
    rank_s1(:), ...
    rank_s2(:)];

nFontes = size(rankings_concordancia,2);

% Nomes simplificados para apresentação
labels_concordancia = strings(nFontes,1);

for e = 1:nExperts
    labels_concordancia(e) = sprintf('E%d',e);
end

labels_concordancia(nExperts+1) = "S1";
labels_concordancia(nExperts+2) = "S2";

% Nomes válidos para as colunas das tabelas MATLAB
nomes_validos = matlab.lang.makeValidName( ...
    cellstr(labels_concordancia));

%% ---------------------------------------------------------
% 2. SPEARMAN FOOTRULE NORMALIZADA
%% ---------------------------------------------------------
%
% Distância Footrule:
%
% F(A,B) = sum_i |r_i^A - r_i^B|
%
% Distância máxima para n elementos:
%
% F_max = floor(n^2/2)
%
% Índice normalizado de concordância:
%
% IC_F = 1 - F/F_max
%
% Interpretação:
%   1 = rankings idênticos
%   0 = distância máxima teórica
%% ---------------------------------------------------------

F_max = floor(nReq^2/2);

IC_footrule = zeros(nFontes,nFontes);
D_footrule  = zeros(nFontes,nFontes);

for a = 1:nFontes

    rank_a = rankings_concordancia(:,a);

    for b = 1:nFontes

        rank_b = rankings_concordancia(:,b);

        % Distância absoluta total entre as posições
        distancia_ab = sum( ...
            abs(rank_a-rank_b), ...
            'omitnan');

        D_footrule(a,b) = distancia_ab;

        % Footrule normalizada como índice de concordância
        IC_footrule(a,b) = 1-distancia_ab/F_max;

        % Proteção contra pequenos erros numéricos ou presença de empates
        IC_footrule(a,b) = max( ...
            0, ...
            min(1,IC_footrule(a,b)));

    end
end


%% ---------------------------------------------------------
% 4. EXIBIÇÃO DAS MATRIZES NO COMMAND WINDOW
%% ---------------------------------------------------------

T_footrule = array2table( ...
    IC_footrule, ...
    'VariableNames',nomes_validos, ...
    'RowNames',cellstr(labels_concordancia));


T_distancia_footrule = array2table( ...
    D_footrule, ...
    'VariableNames',nomes_validos, ...
    'RowNames',cellstr(labels_concordancia));

disp(' ');
disp('--- SPEARMAN FOOTRULE NORMALIZADA ---');
disp(T_footrule);

disp(' ');
disp('--- DISTÂNCIA FOOTRULE NÃO NORMALIZADA ---');
disp(T_distancia_footrule);



%% ---------------------------------------------------------
% 5. HEATMAP — SPEARMAN FOOTRULE NORMALIZADA
%% ---------------------------------------------------------

fig_footrule = figure( ...
    'Color','w', ...
    'Position',[100 80 900 760], ...
    'Visible','on', ...
    'Name', ...
    'Concordância entre especialistas S1 e S2 - Spearman Footrule normalizada', ...
    'NumberTitle','off');

% O heatmap precisa ser criado depois da figura definitiva
imagesc(IC_footrule);

axis square;
box on;

colormap(fig_footrule,parula);

cb = colorbar;
cb.Label.String = 'Concordância Footrule normalizada';

caxis([0 1]);

title( ...
    {'Concordância entre especialistas, S1 e S2', ...
     'Spearman Footrule normalizada'}, ...
    'FontSize',13, ...
    'FontWeight','bold');

xticks(1:nFontes);
yticks(1:nFontes);

xticklabels(labels_concordancia);
yticklabels(labels_concordancia);

xtickangle(45);

xlabel('Fonte de avaliação');
ylabel('Fonte de avaliação');

% Valores dentro das células
for i = 1:nFontes

    for j = 1:nFontes

        valor = IC_footrule(i,j);

        % Texto branco nas células escuras
        if valor < 0.55
            cor_texto = 'w';
        else
            cor_texto = 'k';
        end

        text( ...
            j,i, ...
            sprintf('%.3f',valor), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',9, ...
            'FontWeight','bold', ...
            'Color',cor_texto);

    end
end

set(gca, ...
    'TickLength',[0 0], ...
    'FontSize',10, ...
    'Layer','top');

drawnow;

%% ---------------------------------------------------------
% 7. INDICADORES INDIVIDUAIS DOS ESPECIALISTAS
%% ---------------------------------------------------------
%
% Para cada especialista:
%
% - concordância média com os demais especialistas;
% - concordância com S1;
% - concordância com S2.
%% ---------------------------------------------------------

foot_media_pares = zeros(nExperts,1);
foot_com_s1      = zeros(nExperts,1);
foot_com_s2      = zeros(nExperts,1);


for e = 1:nExperts

    % Índices dos outros especialistas
    outros = setdiff(1:nExperts,e);

    % Footrule
    foot_media_pares(e) = mean( ...
        IC_footrule(e,outros), ...
        'omitnan');

    foot_com_s1(e) = IC_footrule(e,nExperts+1);
    foot_com_s2(e) = IC_footrule(e,nExperts+2);

   
end

Especialista_heatmap = strings(nExperts,1);

for e = 1:nExperts
    Especialista_heatmap(e) = sprintf('E%d',e);
end

T_resumo_concordancia = table( ...
    Especialista_heatmap, ...
    foot_media_pares, ...
    foot_com_s1, ...
    foot_com_s2, ...
    'VariableNames',{ ...
        'Especialista', ...
        'Footrule_Media_Com_Pares', ...
        'Footrule_Com_S1', ...
        'Footrule_Com_S2'});

disp(' ');
disp('--- RESUMO DA CONCORDÂNCIA DOS ESPECIALISTAS ---');
disp(T_resumo_concordancia);

%% ---------------------------------------------------------
% 8. EXPORTAÇÃO PARA EXCEL
%% ---------------------------------------------------------

arquivo_heatmaps = ...
    'Concordancia_Rankings_Especialistas_S1_S2.xlsx';

if isfile(arquivo_heatmaps)

    try
        delete(arquivo_heatmaps);

    catch
        error([ ...
            'Não foi possível substituir o arquivo ', ...
            arquivo_heatmaps, ...
            '. Feche-o no Excel e execute novamente.']);

    end
end

writetable( ...
    T_footrule, ...
    arquivo_heatmaps, ...
    'Sheet','Footrule_Normalizada', ...
    'WriteRowNames',true);

writetable( ...
    T_distancia_footrule, ...
    arquivo_heatmaps, ...
    'Sheet','Distancia_Footrule', ...
    'WriteRowNames',true);



writetable( ...
    T_resumo_concordancia, ...
    arquivo_heatmaps, ...
    'Sheet','Resumo_Especialistas');

fprintf('\nArquivos de concordância criados:\n');
fprintf('%s\n',arquivo_heatmaps);
fprintf('Heatmap_Footrule_Normalizada_Especialistas_S1_S2.png\n');
fprintf('Heatmap_Kendall_Tau_Especialistas_S1_S2.png\n');
%% =========================================================
% 19. FIGURA-RESUMO 4: COMPARAÇÃO DOS TOP 10
%% =========================================================
top10 = min(10, nReq);
req_union = unique([idx_s1(1:top10); idx_s2(1:top10)], 'stable');
labels_union = req_labels(req_union);

figure('Color','w','Position',[140 140 1100 520]);
bar([phi_liq_base(req_union), phi_net(req_union)], 'grouped');
title('Comparação dos requisitos mais relevantes em S1 e S2', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requisitos');
ylabel('\phi_{net}');
legend({'S1','S2'}, 'Location', 'best');
set(gca, 'XTick', 1:numel(req_union), 'XTickLabel', labels_union);
xtickangle(45);
grid on;
box on;
%% =========================================================
% 20. FIGURA-RESUMO 5: BOXPLOT DOS FLUXOS LÍQUIDOS INDIVIDUAIS (S2)

figure('Color','w','Position',[150 150 1150 500]);

boxplot(phi_net_experts', 'Labels', req_labels, 'Whisker', 1.5);

hold on;
plot(1:nReq, phi_net, 'r*', 'MarkerSize', 7); % fluxo agregado do grupo S2
hold off;

title('Boxplot dos fluxos líquidos individuais por requisito (S2)', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requisitos');
ylabel('\phi_{net}');
xtickangle(45);
grid on;
box on;

legend({'Fluxo agregado S2'}, 'Location', 'best');
%% =========================================================
% PROMETHEE I - CENÁRIO S1
% =========================================================

nReq = length(Phi_plus_base);

relation_s1 = zeros(nReq); % matriz de relações PROMETHEE I - S1

for i = 1:nReq
    for j = 1:nReq
        if i == j
            relation_s1(i,j) = 0;
            continue
        end

        if Phi_plus_base(i) > Phi_plus_base(j) && Phi_minus_base(i) < Phi_minus_base(j)
            relation_s1(i,j) = 1;    % i domina j (P)

        elseif Phi_plus_base(i) < Phi_plus_base(j) && Phi_minus_base(i) > Phi_minus_base(j)
            relation_s1(i,j) = -1;   % j domina i (P-)

        elseif Phi_plus_base(i) > Phi_plus_base(j) && Phi_minus_base(i) > Phi_minus_base(j)
            relation_s1(i,j) = 2;    % incomparável (R)

        elseif Phi_plus_base(i) < Phi_plus_base(j) && Phi_minus_base(i) < Phi_minus_base(j)
            relation_s1(i,j) = 2;    % incomparável (R)

        else
            relation_s1(i,j) = 0;    % indiferença (I)
        end
    end
end

%% =========================================================
% PARES INCOMPARÁVEIS - S1
% =========================================================

req_i_s1 = strings(0,1);
req_j_s1 = strings(0,1);

for i = 1:nReq
    for j = i+1:nReq   % só metade superior para evitar duplicidade
        if relation_s1(i,j) == 2
            req_i_s1(end+1,1) = string(req_labels{i});
            req_j_s1(end+1,1) = string(req_labels{j});
        end
    end
end

T_incomp_s1 = table(req_i_s1, req_j_s1, ...
    'VariableNames', {'Req_1','Req_2'});
% 
% disp(' ')
% disp('--- PARES INCOMPARÁVEIS NO PROMETHEE I - S1 ---')
% disp(T_incomp_s1)

writetable(T_incomp_s1, 'PROMETHEE_I_Incomparable_Pairs_S1.xlsx');

%% =========================================================
% MATRIZ DE RELAÇÕES PROMETHEE I - S1
% =========================================================
figure('Color','w','Position',[260 190 720 620])

imagesc(relation_s1)

% Colormap customizado:
% ordem: [-1, 0, 1, 2]
cmap = [
    0.2 0.2 0.8   % azul   → P- (dominado)
    0.7 0.7 0.7   % cinza  → I (indiferente)
    0.2 0.7 0.2   % verde  → P (domina)
    0.9 0.8 0.2   % amarelo→ R (incomparável)
];

colormap(cmap)

% Ajusta escala para mapear corretamente
caxis([-1 2])

colorbar('Ticks',[-1 0 1 2], ...
         'TickLabels',{'P- (Dominado)','I (Indiferente)','P (Domina)','R (Incomparável)'})

title('PROMETHEE I relations - Scenario S1')
xlabel('Alternative j')
ylabel('Alternative i')
set(gca,'XTick',1:nReq,'XTickLabel',req_labels)
set(gca,'YTick',1:nReq,'YTickLabel',req_labels)

xtickangle(90)
grid on
box on

%% =========================================================
% EXPORTAR MATRIZ DE RELAÇÕES PROMETHEE I - S1
% =========================================================
rel_matrix_text_s1 = cell(nReq, nReq);

for i = 1:nReq
    for j = 1:nReq
        if i == j
            rel_matrix_text_s1{i,j} = '-';
        else
            switch relation_s1(i,j)
                case 1
                    rel_matrix_text_s1{i,j} = 'P (Outranks)';
                case -1
                    rel_matrix_text_s1{i,j} = 'P- (Outranked)';
                case 2
                    rel_matrix_text_s1{i,j} = 'R (Incomparable)';
                case 0
                    rel_matrix_text_s1{i,j} = 'I (Indifferent)';
            end
        end
    end
end

T_rel_matrix_s1 = cell2table(rel_matrix_text_s1, ...
    'VariableNames', req_labels, ...
    'RowNames', req_labels);

writetable(T_rel_matrix_s1, 'PROMETHEE_I_Relation_Matrix_S1.xlsx', 'WriteRowNames', true);

disp(' ')
disp('--- PROMETHEE I relation matrix exported for S1 ---')
disp('File: PROMETHEE_I_Relation_Matrix_S1.xlsx')

%% =========================================================
% KENDALL W DOS PESOS FAHP
%% =========================================================

% Defuzzificação dos pesos fuzzy individuais
w_defuzz_individual = zeros(nCrit,nExperts);

for e = 1:nExperts

    for k = 1:nCrit

        wf = squeeze(info_s2.w_fuzzy_individual(k,:,e));

        % Centroide para trapézio
        w_defuzz_individual(k,e) = ...
            (wf(1) + 2*wf(2) + 2*wf(3) + wf(4))/6;

    end

end

% Ranking dos critérios para cada especialista
rank_weights = zeros(size(w_defuzz_individual));

for e = 1:nExperts

    rank_weights(:,e) = tiedrank(-w_defuzz_individual(:,e));

end

% Kendall W
R = rank_weights;

[n,m] = size(R);

Ri = sum(R,2);
Rbar = mean(Ri);

S = sum((Ri - Rbar).^2);

W_fahp = 12*S/(m^2*(n^3-n));

chi2_fahp = m*(n-1)*W_fahp;

p_fahp = 1 - chi2cdf(chi2_fahp,n-1);

disp(' ')
disp('========================================')
disp('KENDALL W DOS PESOS FAHP')
disp('========================================')

fprintf('W = %.4f\n',W_fahp);
fprintf('Chi2 = %.4f\n',chi2_fahp);
fprintf('p-value = %.6f\n',p_fahp);

%% kendel

R = rank_matrix(:,1:nExperts);

[n,m] = size(R);

% soma dos ranks por requisito
Ri = sum(R,2);

% rank médio total
Rbar = mean(Ri);

% estatística S
S = sum((Ri - Rbar).^2);

% Kendall W
W = 12*S / (m^2*(n^3 - n));

fprintf('Kendall W = %.4f\n',W);

chi2 = m*(n-1)*W;

p = 1 - chi2cdf(chi2,n-1);

fprintf('Chi2 = %.4f\n',chi2);
fprintf('p-value = %.6f\n',p);

%% =========================================================
% PROMETHEE I - CENÁRIO S2
% =========================================================

nReq = length(Phi_plus);

relation_s2 = zeros(nReq); % matriz de relações PROMETHEE I - S2

for i = 1:nReq
    for j = 1:nReq
        if i == j
            relation_s2(i,j) = 0;
            continue
        end

        if Phi_plus(i) > Phi_plus(j) && Phi_minus(i) < Phi_minus(j)
            relation_s2(i,j) = 1;    % i domina j (P)

        elseif Phi_plus(i) < Phi_plus(j) && Phi_minus(i) > Phi_minus(j)
            relation_s2(i,j) = -1;   % j domina i (P-)

        elseif Phi_plus(i) > Phi_plus(j) && Phi_minus(i) > Phi_minus(j)
            relation_s2(i,j) = 2;    % incomparável (R)

        elseif Phi_plus(i) < Phi_plus(j) && Phi_minus(i) < Phi_minus(j)
            relation_s2(i,j) = 2;    % incomparável (R)

        else
            relation_s2(i,j) = 0;    % indiferença (I)
        end
    end
end
%% =========================================================
% PARES INCOMPARÁVEIS - S2
% =========================================================

req_i_s2 = strings(0,1);
req_j_s2 = strings(0,1);

for i = 1:nReq
    for j = i+1:nReq   % só metade superior para evitar duplicidade
        if relation_s2(i,j) == 2
            req_i_s2(end+1,1) = string(req_labels{i});
            req_j_s2(end+1,1) = string(req_labels{j});
        end
    end
end

T_incomp_s2 = table(req_i_s2, req_j_s2, ...
    'VariableNames', {'Req_1','Req_2'});

% disp(' ')
% disp('--- PARES INCOMPARÁVEIS NO PROMETHEE I - S2 ---')
% disp(T_incomp_s2)

writetable(T_incomp_s2, 'PROMETHEE_I_Incomparable_Pairs_S2.xlsx');

%% =========================================================
% MATRIZ DE RELAÇÕES PROMETHEE I - S2 (COM LEGENDA)
% =========================================================
figure('Color','w','Position',[310 210 720 620])

imagesc(relation_s2)

% Colormap discreto (ordem: -1, 0, 1, 2)
cmap = [
    0.2 0.2 0.8   % azul   → P- (dominado)
    0.7 0.7 0.7   % cinza  → I (indiferente)
    0.2 0.7 0.2   % verde  → P (domina)
    0.9 0.8 0.2   % amarelo→ R (incomparável)
];

colormap(cmap)

% Ajuste da escala
caxis([-1 2])

% Colorbar com significado
colorbar('Ticks',[-1 0 1 2], ...
         'TickLabels',{'P- (Dominado)','I (Indiferente)','P (Domina)','R (Incomparável)'})

title('PROMETHEE I relations - Scenario S2')
xlabel('Alternative j')
ylabel('Alternative i')

set(gca,'XTick',1:nReq,'XTickLabel',req_labels)
set(gca,'YTick',1:nReq,'YTickLabel',req_labels)

xtickangle(90)
grid on
box on

%% =========================================================
% EXPORTAR MATRIZ DE RELAÇÕES PROMETHEE I - S2
% =========================================================
rel_matrix_text_s2 = cell(nReq, nReq);

for i = 1:nReq
    for j = 1:nReq
        if i == j
            rel_matrix_text_s2{i,j} = '-';
        else
            switch relation_s2(i,j)
                case 1
                    rel_matrix_text_s2{i,j} = 'P (Outranks)';
                case -1
                    rel_matrix_text_s2{i,j} = 'P- (Outranked)';
                case 2
                    rel_matrix_text_s2{i,j} = 'R (Incomparable)';
                case 0
                    rel_matrix_text_s2{i,j} = 'I (Indifferent)';
            end
        end
    end
end

T_rel_matrix_s2 = cell2table(rel_matrix_text_s2, ...
    'VariableNames', req_labels, ...
    'RowNames', req_labels);

writetable(T_rel_matrix_s2, 'PROMETHEE_I_Relation_Matrix_S2.xlsx', 'WriteRowNames', true);

% disp(' ')
% disp('--- PROMETHEE I relation matrix exported for S2 ---')
% disp('File: PROMETHEE_I_Relation_Matrix_S2.xlsx')



%% =========================================================
% RESUMO DAS RELAÇÕES PROMETHEE I - S1 vs S2
% =========================================================

count_relations = @(R) struct( ...
    'P',  sum(R(:) == 1), ...
    'Pm', sum(R(:) == -1), ...
    'R',  sum(R(:) == 2), ...
    'I',  sum(R(:) == 0) - nReq ); % desconta diagonal

rel_s1 = count_relations(relation_s1);
rel_s2 = count_relations(relation_s2);

T_prom1_compare = table( ...
    ["S1"; "S2"], ...
    [rel_s1.P;  rel_s2.P], ...
    [rel_s1.Pm; rel_s2.Pm], ...
    [rel_s1.R;  rel_s2.R], ...
    [rel_s1.I;  rel_s2.I], ...
    'VariableNames', {'Scenario','P_Outranks','Pminus_Outranked','R_Incomparable','I_Indifferent'});

% disp(' ')
% disp('--- PROMETHEE I relation summary: S1 vs S2 ---')
% disp(T_prom1_compare)

writetable(T_prom1_compare, 'PROMETHEE_I_Summary_S1_S2.xlsx');

%% =========================================================
% QUANTIDADE DE INCOMPARABILIDADES POR REQUISITO - S1
% =========================================================

num_incomp_s1 = zeros(nReq,1);

for i = 1:nReq
    num_incomp_s1(i) = sum(relation_s1(i,:) == 2);
end

T_num_incomp_s1 = table(req_labels(:), IDs, num_incomp_s1, ...
    'VariableNames', {'Req','ID','NumIncomparabilities_S1'});

T_num_incomp_s1 = sortrows(T_num_incomp_s1, 'NumIncomparabilities_S1', 'descend');

% disp(' ')
% disp('--- QUANTIDADE DE INCOMPARABILIDADES POR REQUISITO - S1 ---')
% disp(T_num_incomp_s1)

writetable(T_num_incomp_s1, 'PROMETHEE_I_Num_Incomparabilities_S1.xlsx');

%% =========================================================
% QUANTIDADE DE INCOMPARABILIDADES POR REQUISITO - S2
% =========================================================

num_incomp_s2 = zeros(nReq,1);

for i = 1:nReq
    num_incomp_s2(i) = sum(relation_s2(i,:) == 2);
end

T_num_incomp_s2 = table(req_labels(:), IDs, num_incomp_s2, ...
    'VariableNames', {'Req','ID','NumIncomparabilities_S2'});

T_num_incomp_s2 = sortrows(T_num_incomp_s2, 'NumIncomparabilities_S2', 'descend');
% 
% disp(' ')
% disp('--- QUANTIDADE DE INCOMPARABILIDADES POR REQUISITO - S2 ---')
% disp(T_num_incomp_s2)

writetable(T_num_incomp_s2, 'PROMETHEE_I_Num_Incomparabilities_S2.xlsx');

%% =========================================================
% COMPARAÇÃO DAS INCOMPARABILIDADES - S1 vs S2
% =========================================================

req_i = strings(0,1);
req_j = strings(0,1);
incomp_s1_col = false(0,1);
incomp_s2_col = false(0,1);

for i = 1:nReq
    for j = i+1:nReq
        s1_inc = (relation_s1(i,j) == 2);
        s2_inc = (relation_s2(i,j) == 2);

        if s1_inc || s2_inc
            req_i(end+1,1) = string(req_labels{i});
            req_j(end+1,1) = string(req_labels{j});
            incomp_s1_col(end+1,1) = s1_inc;
            incomp_s2_col(end+1,1) = s2_inc;
        end
    end
end

T_incomp_compare = table(req_i, req_j, incomp_s1_col, incomp_s2_col, ...
    'VariableNames', {'Req_1','Req_2','Incomparable_S1','Incomparable_S2'});

% disp(' ')
% disp('--- COMPARAÇÃO DAS INCOMPARABILIDADES S1 vs S2 ---')
% disp(T_incomp_compare)

writetable(T_incomp_compare, 'PROMETHEE_I_Incomparabilities_S1_S2.xlsx');
%% =========================================================
% GRÁFICO: NÚMERO DE INCOMPARABILIDADES POR REQUISITO (S1 vs S2)
% =========================================================

figure('Color','w','Position',[180 140 1100 480]);
bar([num_incomp_s1, num_incomp_s2], 'grouped');

title('Number of PROMETHEE I incomparabilities per requirement', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requirements');
ylabel('Number of incomparable relations');
legend({'S1','S2'}, 'Location', 'best');
set(gca, 'XTick', 1:nReq, 'XTickLabel', req_labels);
xtickangle(45);
grid on;
box on;
%% =========================================================
% GAIA PLANE FIEL AO PROMETHEE (via fluxos líquidos unicritério)
%% =========================================================

% Matriz dos fluxos líquidos unicritério do cenário S2 agregado
% linhas = requisitos
% colunas = critérios
Phi_uni = computeUnicriterionNetFlows(F, w_group_defuzz, critDir, pref_types, q_vals, p_vals);

% Normalização/centragem para GAIA
Phi_uni_z = zscore(Phi_uni);

% PCA sobre a matriz de fluxos unicritério
[coeff_gaia, score_gaia, latent_gaia] = pca(Phi_uni_z);

U = score_gaia(:,1);
V = score_gaia(:,2);

% Delta do plano GAIA
delta_gaia = 100 * sum(latent_gaia(1:min(2,end))) / sum(latent_gaia);

fprintf('\nDelta do plano GAIA = %.2f%%\n', delta_gaia);

if delta_gaia >= 80
    fprintf('Interpretação: plano GAIA muito representativo.\n');
elseif delta_gaia >= 60
    fprintf('Interpretação: plano GAIA razoavelmente representativo.\n');
else
    fprintf('Interpretação: plano GAIA deve ser interpretado com cautela.\n');
end

figure('Color','w','Position',[260 160 920 700])
hold on

% alternativas
scatter(U, V, 80, phi_net, 'filled')
colorbar
colormap(parula)

for i = 1:nReq
    text(U(i), V(i), req_labels{i}, 'FontSize', 9)
end

% vetores dos critérios
for k = 1:nCrit
    quiver(0, 0, coeff_gaia(k,1), coeff_gaia(k,2), 0, ...
        'LineWidth', 2, 'Color', 'k');

    text(coeff_gaia(k,1)*1.15, coeff_gaia(k,2)*1.15, crit_names{k}, ...
        'FontWeight', 'bold');
end

% vetor de decisão (pi-stick aproximado pelos pesos no espaço projetado)
decision_stick = w_group_defuzz(:)' * coeff_gaia(:,1:2);
quiver(0, 0, decision_stick(1), decision_stick(2), 0, ...
    'LineWidth', 3, 'LineStyle', '--', 'Color', [0.2 0.2 0.2]);

text(decision_stick(1)*1.08, decision_stick(2)*1.08, 'Pi', ...
    'FontWeight', 'bold', 'FontSize', 11, 'Color', [0.2 0.2 0.2]);

xlabel(sprintf('GAIA axis 1 (%.1f%%)', 100*latent_gaia(1)/sum(latent_gaia)))
ylabel(sprintf('GAIA axis 2 (%.1f%%)', 100*latent_gaia(2)/sum(latent_gaia)))
title(sprintf('GAIA plane baseado em fluxos líquidos unicritério (\\delta = %.2f%%)', delta_gaia), ...
    'FontWeight', 'bold')

text(min(U), max(V)*1.06, ...
    sprintf('\\delta = %.2f%% da informação preservada no plano', delta_gaia), ...
    'FontSize', 11, 'FontWeight', 'bold')

grid on
axis equal
box on
hold off

%% =========================================================
% MUDANÇAS DE RELAÇÕES PROMETHEE I: S1 vs S2
% =========================================================

change_per_req_prom1 = zeros(nReq,1);

for i = 1:nReq
    % conta quantas relações da linha i mudaram entre S1 e S2
    change_per_req_prom1(i) = sum(relation_s1(i,:) ~= relation_s2(i,:));
end

T_prom1_req_changes = table(req_labels(:), IDs, change_per_req_prom1, ...
    'VariableNames', {'Req','ID','NumRelationChanges_S1_to_S2'});

T_prom1_req_changes = sortrows(T_prom1_req_changes, 'NumRelationChanges_S1_to_S2', 'descend');

% disp(' ')
% disp('--- REQUISITOS QUE MAIS MUDARAM NO PROMETHEE I (S1 vs S2) ---')
% disp(T_prom1_req_changes)

writetable(T_prom1_req_changes, 'PROMETHEE_I_Requirement_Changes_S1_S2.xlsx');

%% =========================================================
% GRÁFICO: NÚMERO DE MUDANÇAS DE RELAÇÃO POR REQUISITO
% =========================================================

[~, ord_prom1_changes] = sort(change_per_req_prom1, 'descend');

figure('Color','w','Position',[180 140 1100 450]);
bar(categorical(req_labels(ord_prom1_changes)), change_per_req_prom1(ord_prom1_changes));

title('Number of PROMETHEE I relation changes per requirement (S1 vs S2)', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requirements');
ylabel('Number of changed pairwise relations');
grid on;
box on;
xtickangle(45);

%% QTD DE INCOMPARABILIDADES
%% =========================================================
% RESUMO DE INCOMPARABILIDADES
% =========================================================

total_pairs = nReq*(nReq-1)/2;

num_incomp_s1_total = sum(triu(relation_s1==2,1),'all');
num_incomp_s2_total = sum(triu(relation_s2==2,1),'all');

perc_s1 = 100*num_incomp_s1_total/total_pairs;
perc_s2 = 100*num_incomp_s2_total/total_pairs;

fprintf('\n');
fprintf('========================================\n');
fprintf('PROMETHEE I - INCOMPARABILIDADES\n');
fprintf('========================================\n');

fprintf('S1 = %d pares incomparáveis (%.2f%%)\n', ...
        num_incomp_s1_total, perc_s1);

fprintf('S2 = %d pares incomparáveis (%.2f%%)\n', ...
        num_incomp_s2_total, perc_s2);

%% =========================================================
% DELTA DE RANK
%% =========================================================

delta_rank = rank_s2 - rank_s1;

mean_delta_rank = mean(abs(delta_rank));

max_delta_rank  = max(abs(delta_rank));

fprintf('\n');
fprintf('========================================\n');
fprintf('ESTABILIDADE DOS RANKINGS\n');
fprintf('========================================\n');

fprintf('Media |Δ Rank| = %.2f\n',mean_delta_rank);
fprintf('Maximo |Δ Rank| = %d\n',max_delta_rank);

[~,ord_s1] = sort(phi_liq_base,'descend');
[~,ord_s2] = sort(phi_net,'descend');

top10_s1 = ord_s1(1:10);
top10_s2 = ord_s2(1:10);

%% =========================================================
% TOP-10 OVERLAP
%% =========================================================

top10 = min(10,nReq);

top10_s1 = idx_s1(1:top10);
top10_s2 = idx_s2(1:top10);

top10_comum = intersect(top10_s1,top10_s2);

num_overlap = length(top10_comum);

perc_overlap = 100*num_overlap/top10;

fprintf('\n');
fprintf('========================================\n');
fprintf('TOP-%d OVERLAP\n',top10);
fprintf('========================================\n');

fprintf('Top comum = %d de %d\n', ...
        num_overlap,top10);

fprintf('Overlap = %.1f %%\n', ...
        perc_overlap);

disp('Requisitos presentes nos dois Top-10:')
disp(req_labels(top10_comum)')

union_top10 = union(top10_s1,top10_s2);

jaccard_top10 = ...
    length(intersect(top10_s1,top10_s2)) / ...
    length(union_top10);

fprintf('Jaccard Top-10 = %.3f\n', ...
        jaccard_top10);


%% =========================================================
% DELTA DE RANK
%% =========================================================

delta_rank = rank_s2 - rank_s1;

mean_delta_rank = mean(abs(delta_rank));

max_delta_rank  = max(abs(delta_rank));

fprintf('\n');
fprintf('========================================\n');
fprintf('ESTABILIDADE DOS RANKINGS\n');
fprintf('========================================\n');

fprintf('Media |Δ Rank| = %.2f\n',mean_delta_rank);
fprintf('Maximo |Δ Rank| = %d\n',max_delta_rank);

[~,ord_s1] = sort(phi_liq_base,'descend');
[~,ord_s2] = sort(phi_net,'descend');

top10_s1 = ord_s1(1:10);
top10_s2 = ord_s2(1:10);


% RESUMO DE INCOMPARABILIDADES
% =========================================================

total_pairs = nReq*(nReq-1)/2;

num_incomp_s1_total = sum(triu(relation_s1==2,1),'all');
num_incomp_s2_total = sum(triu(relation_s2==2,1),'all');

perc_s1 = 100*num_incomp_s1_total/total_pairs;
perc_s2 = 100*num_incomp_s2_total/total_pairs;

fprintf('\n');
fprintf('========================================\n');
fprintf('PROMETHEE I - INCOMPARABILIDADES\n');
fprintf('========================================\n');

fprintf('S1 = %d pares incomparáveis (%.2f%%)\n', ...
        num_incomp_s1_total, perc_s1);

fprintf('S2 = %d pares incomparáveis (%.2f%%)\n', ...
        num_incomp_s2_total, perc_s2);

%% =========================================================
% COMPARAÇÃO S1 E S2
%% =========================================================
% RESUMO EXECUTIVO S1 x S2
%% =========================================================

T_comp = table( ...
    { ...
    'Incomparabilidades'; ...
    '% Incomparabilidades'; ...
    'Media |Delta Rank|'; ...
    'Max |Delta Rank|'; ...
    'Top-10 Overlap'; ...
    'Overlap (%)'; ...
    'Jaccard Top-10'; ...
    'Spearman Rank' ...
    }, ...
    [ ...
    num_incomp_s1_total; ...
    perc_s1; ...
    NaN; ...
    NaN; ...
    NaN; ...
    NaN; ...
    NaN; ...
    NaN ...
    ], ...
    [ ...
    num_incomp_s2_total; ...
    perc_s2; ...
    mean_delta_rank; ...
    max_delta_rank; ...
    num_overlap; ...
    perc_overlap; ...
    jaccard_top10; ...
   rho_s1_s2 ...
    ], ...
    'VariableNames',{ ...
    'Indicador', ...
    'S1', ...
    'S2' ...
    });

writetable(T_comp,...
    'Comparacao_S1_S2.xlsx',...
    'Sheet','Resumo');

%% =========================================================
% EXPORTAR MATRIZ UNICRITÉRIO E INDICADORES GAIA
%% =========================================================

T_phi_uni = array2table(Phi_uni, ...
    'VariableNames', matlab.lang.makeValidName(crit_names), ...
    'RowNames', req_labels);

writetable(T_phi_uni, 'GAIA_Fluxos_Unicriterio.xlsx', 'WriteRowNames', true);

T_gaia = table(delta_gaia, ...
               100*latent_gaia(1)/sum(latent_gaia), ...
               100*latent_gaia(2)/sum(latent_gaia), ...
    'VariableNames', {'Delta_GAIA_percent', 'Axis1_percent', 'Axis2_percent'});

writetable(T_gaia, 'Indicadores_GAIA.xlsx');

% disp(' ');
% disp('--- MATRIZ DE FLUXOS UNICRITÉRIO E INDICADORES GAIA EXPORTADOS ---');
% disp(T_gaia);
% %% =========================================================
% figure
% gscatter(rank_s2,phi_net,cat)
% 
% xlabel('Ranking S2')
% ylabel('\phi_{net}')
% title('Classificação dos requisitos')
% grid on


%% =========================================================
% HEATMAP DAS CLASSIFICAÇÕES
%% =========================================================

cat_matrix = [cat_exp, cat_s2, cat_s1];

cat_labels = cell(1,nExperts+2);

for e = 1:nExperts
    cat_labels{e} = sprintf('E%d',e);
end

cat_labels{nExperts+1} = 'S2';
cat_labels{nExperts+2} = 'S1';

cat_code = zeros(size(cat_matrix));

for j = 1:size(cat_matrix,2)
    cat_code(:,j) = classToCode(cat_matrix(:,j));
end

[~, ord_cat] = sort(rank_s2,'ascend');

fig_classificacoes = figure( ...
    'Color','w', ...
    'Position',[120 80 1100 720], ...
    'Visible','on', ...
    'Name','Heatmap das classificações dos requisitos', ...
    'NumberTitle','off');

imagesc(cat_code(ord_cat,:));

colormap(parula(4));

colorbar('Ticks',1:4,...
         'TickLabels',{'Key','G1','G2','G3'});

title('Heatmap das classificações por fonte',...
      'FontSize',13,'FontWeight','bold');

xlabel('Fonte');
ylabel('Requisitos');

xticks(1:numel(cat_labels));
xticklabels(cat_labels);

yticks(1:nReq);
yticklabels(req_labels(ord_cat));

for i = 1:nReq
    for j = 1:size(cat_code,2)

        txt = string(cat_matrix(ord_cat(i),j));

        text(j,i,txt,...
            'HorizontalAlignment','center',...
            'FontSize',8,...
            'FontWeight','bold',...
            'Color','k');
    end
end

set(gca,'TickLength',[0 0]);
box on;

%% =========================================================
% CONSENSO DE CLASSIFICAÇÃO POR REQUISITO
%
% Mede o percentual de especialistas que atribuíram
% exatamente a mesma classe do resultado consolidado S2.
%% =========================================================

percentual_consenso = zeros(nReq,1);

for i = 1:nReq

    percentual_consenso(i) = ...
        100*mean(cat_exp(i,:) == cat_s2(i));

end

T_consenso_classe = table( ...
    req_labels(:), ...
    cat_s2(:), ...
    percentual_consenso, ...
    'VariableNames', ...
    {'Requisito','Classe_S2','PercentualConsenso'});

T_consenso_classe = sortrows( ...
    T_consenso_classe, ...
    'PercentualConsenso', ...
    'descend');

disp(' ')
disp('--- CONSENSO DE CLASSIFICAÇÃO POR REQUISITO ---')
disp(T_consenso_classe)

%% ---------------------------------------------------------
% GRÁFICO
%% ---------------------------------------------------------

figure('Color','w','Position',[220 150 1100 450]);

bar(categorical(T_consenso_classe.Requisito), ...
    T_consenso_classe.PercentualConsenso);

ylim([0 100]);

ylabel('Especialistas concordando com S2 (%)');

xlabel('Requisitos');

title('Consenso dos especialistas em relação à classificação consolidada (S2)', ...
    'FontSize',13,...
    'FontWeight','bold');

grid on;
box on;
%% =========================================================
% EXPORTAR TABELA APENAS DAS CLASSIFICAÇÕES
%% =========================================================

vars = {req_labels(:), IDs};

varNames = {'Req','ID'};

for e = 1:nExperts

    vars{end+1} = cat_exp(:,e);
    varNames{end+1} = sprintf('Classe_E%d',e);

end

vars{end+1} = cat_s2(:);
vars{end+1} = cat_s1(:);

varNames{end+1} = 'Classe_S2';
varNames{end+1} = 'Classe_S1';

T_classes = table(vars{:},...
                  'VariableNames',varNames);

% writetable(T_classes,'Comparacao_Classificacoes.xlsx');
% disp(' ')
% disp('--- TABELA DE CLASSIFICAÇÕES EXPORTADA ---')
% disp(T_classes)

%% =========================================================
% MATRIZ COMPLETA DE MUDANÇAS DE CLASSIFICAÇÃO
%% =========================================================

% Classificações dos especialistas, grupo S2 e cenário S1
cat_matrix = [cat_exp, cat_s2(:), cat_s1(:)];

% Rótulos dinâmicos
cat_labels = cell(1, nExperts + 2);

for e = 1:nExperts
    cat_labels{e} = sprintf('E%d', e);
end

cat_labels{nExperts + 1} = 'S2';
cat_labels{nExperts + 2} = 'S1';

nSources = size(cat_matrix, 2);
change_matrix = zeros(nSources, nSources);

for i = 1:nSources
    for j = 1:nSources
        change_matrix(i,j) = sum(cat_matrix(:,i) ~= cat_matrix(:,j));
    end
end

figure('Color','w','Position',[220 160 760 650]);

imagesc(change_matrix);
colormap(flipud(parula));
colorbar;
axis square;

title('Matriz de mudanças de classificação entre fontes', ...
    'FontSize', 13, ...
    'FontWeight', 'bold');

xlabel('Fonte');
ylabel('Fonte');

xticks(1:nSources);
yticks(1:nSources);

xticklabels(cat_labels);
yticklabels(cat_labels);

for i = 1:nSources
    for j = 1:nSources
        text(j, i, num2str(change_matrix(i,j)), ...
            'HorizontalAlignment', 'center', ...
            'FontSize', 10, ...
            'FontWeight', 'bold', ...
            'Color', 'k');
    end
end

box on;
%% =========================================================
% BOXPLOT DAS AVALIAÇÕES DE IMPACTO POR REQUISITO
%% =========================================================

figure('Color','w','Position',[200 160 1200 500]);
boxplot(impacto_ind', 'Labels', req_labels, 'Whisker', 1.5);

hold on;
plot(1:nReq, mean(impacto_ind,2), 'r*', 'MarkerSize', 7);
hold off;

title('Boxplot das avaliações de Impacto na Missão por requisito', ...
    'FontSize', 13, 'FontWeight', 'bold');
xlabel('Requisitos');
ylabel('Nota de Impacto');
xtickangle(45);
grid on;
box on;
legend({'Média do Impacto'}, 'Location', 'best');

%% =========================================================
% SCATTER: PHI_NET VS DISPERSÃO
%% =========================================================

figure('Color','w','Position',[220 180 850 620]);
scatter(phi_net, disp_std_media_req, 90, classToCode(cat), 'filled');
colorbar('Ticks',1:4,'TickLabels',{'Key','G1','G2','G3'});
colormap(parula(4));
hold on;

for i = 1:nReq
    text(phi_net(i), disp_std_media_req(i), [' ' req_labels{i}], ...
        'FontSize', 8, 'FontWeight', 'bold');
end

xlabel('\phi_{net} (prioridade agregada)');
ylabel('Dispersão média das avaliações (desvio-padrão)');
title('\phi_{net} versus dispersão das avaliações por requisito', ...
    'FontSize', 13, 'FontWeight', 'bold');
grid on;
box on;
hold off;

%% =========================================================
% SCATTER: PHI_NET VS DISPERSÃO EM IMPACTO
%% =========================================================

figure('Color','w','Position',[240 200 850 620]);
scatter(phi_net, impacto_range, 90, classToCode(cat), 'filled');
colorbar('Ticks',1:4,'TickLabels',{'Key','G1','G2','G3'});
colormap(parula(4));
hold on;

for i = 1:nReq
    text(phi_net(i), impacto_range(i), [' ' req_labels{i}], ...
        'FontSize', 8, 'FontWeight', 'bold');
end

xlabel('\phi_{net} (prioridade agregada)');
ylabel('Amplitude das notas de Impacto (max - min)');
title('\phi_{net} versus divergência em Impacto na Missão', ...
    'FontSize', 13, 'FontWeight', 'bold');
grid on;
box on;
hold off;

%% =========================================================
% HEATMAP DE DIVERGÊNCIA POR ESPECIALISTA
%% =========================================================

for e = 1:nExperts

    dev_matrix = zeros(nReq,nCrit);

    for i = 1:nReq

        for k = 1:nCrit

            vals = squeeze(data_all(i,k,:));

            med_val = median(vals);

            dev_matrix(i,k) = abs(vals(e) - med_val);

        end

    end

    % ordenar pelos requisitos onde ESTE especialista mais divergiu
    [~,ord_req] = sort(mean(dev_matrix,2),'descend');

    figure('Color','w',...
           'Position',[150 100 900 700]);

    imagesc(dev_matrix(ord_req,:));

    colormap(parula);
    colorbar;

    title(sprintf('Divergência do E%d em relação à mediana do grupo',e),...
          'FontSize',13,...
          'FontWeight','bold');

    xlabel('Critérios');
    ylabel('Requisitos');

    xticks(1:nCrit);
    xticklabels(crit_names);

    yticks(1:nReq);
    yticklabels(req_labels(ord_req));

    for r = 1:nReq
        for c = 1:nCrit

            text(c,r,...
                sprintf('%.0f',dev_matrix(ord_req(r),c)),...
                'HorizontalAlignment','center',...
                'FontWeight','bold',...
                'FontSize',8,...
                'Color','k');

        end
    end

    box on;

end

%% =========================================================
% TABELA FINAL: RANK + GRUPO + INCOMPARABILIDADE LOCAL
% Regras:
% 1) vizinho imediato acima/abaixo
% 2) contagem global de incomparabilidades
% 3) checagem ampliada de 3 posicoes acima/abaixo
% =========================================================

% ordenar pelo ranking S2 (PROMETHEE II)
[~, ord_rank] = sort(rank_s2, 'ascend');

Req_ord   = req_labels(ord_rank);
Rank_ord  = rank_s2(ord_rank);
Phi_ord   = phi_net(ord_rank);
Grupo_ord = cat(ord_rank);

% se IDs existir no seu workspace, use:
if exist('IDs','var')
    ID_ord = IDs(ord_rank);
else
    ID_ord = (1:nReq)';
    ID_ord = ID_ord(ord_rank);
end

% ---------------------------------------------------------
% REGRA 2: contagem global de incomparabilidades
% ---------------------------------------------------------
num_incomp_global = zeros(nReq,1);
for i = 1:nReq
    num_incomp_global(i) = sum(relation_s2(i,:) == 2);
end
NumIncomp_ord = num_incomp_global(ord_rank);

FlagGlobal = strings(nReq,1);
for k = 1:nReq
    if NumIncomp_ord(k) <= 2
        FlagGlobal(k) = "Baixa";
    elseif NumIncomp_ord(k) <= 5
        FlagGlobal(k) = "Média";
    else
        FlagGlobal(k) = "Alta";
    end
end

% ---------------------------------------------------------
% REGRA 1: incomparabilidade com vizinho imediato
% ---------------------------------------------------------
Inc_Acima_1  = strings(nReq,1);
Inc_Abaixo_1 = strings(nReq,1);

for k = 1:nReq
    i = ord_rank(k);

    if k == 1
        Inc_Acima_1(k) = "-";
    else
        j_up = ord_rank(k-1);
        if relation_s2(i,j_up) == 2
            Inc_Acima_1(k) = "Sim";
        else
            Inc_Acima_1(k) = "Não";
        end
    end

    if k == nReq
        Inc_Abaixo_1(k) = "-";
    else
        j_down = ord_rank(k+1);
        if relation_s2(i,j_down) == 2
            Inc_Abaixo_1(k) = "Sim";
        else
            Inc_Abaixo_1(k) = "Não";
        end
    end
end

% ---------------------------------------------------------
% REGRA 3: checagem ampliada (até 3 posições acima/abaixo)
% ---------------------------------------------------------
Inc_Acima_3  = strings(nReq,1);
Inc_Abaixo_3 = strings(nReq,1);
Qtd_Acima_3  = zeros(nReq,1);
Qtd_Abaixo_3 = zeros(nReq,1);

for k = 1:nReq
    i = ord_rank(k);

    % acima (ate 3 posicoes)
    idx_up = max(1, k-3):(k-1);
    if isempty(idx_up)
        Inc_Acima_3(k) = "-";
    else
        count_up = 0;
        for t = idx_up
            j = ord_rank(t);
            if relation_s2(i,j) == 2
                count_up = count_up + 1;
            end
        end
        Qtd_Acima_3(k) = count_up;
        if count_up > 0
            Inc_Acima_3(k) = "Sim";
        else
            Inc_Acima_3(k) = "Não";
        end
    end

    % abaixo (ate 3 posicoes)
    idx_down = (k+1):min(nReq, k+3);
    if isempty(idx_down)
        Inc_Abaixo_3(k) = "-";
    else
        count_down = 0;
        for t = idx_down
            j = ord_rank(t);
            if relation_s2(i,j) == 2
                count_down = count_down + 1;
            end
        end
        Qtd_Abaixo_3(k) = count_down;
        if count_down > 0
            Inc_Abaixo_3(k) = "Sim";
        else
            Inc_Abaixo_3(k) = "Não";
        end
    end
end

% ---------------------------------------------------------
% LEITURA FINAL
% prioridade da leitura:
% 1. fronteira critica
% 2. zona cinzenta
% 3. atencao local
% 4. alerta estrutural
% 5. robusto
% ---------------------------------------------------------
Leitura = strings(nReq,1);

for k = 1:nReq

    mudou_grupo_acima  = false;
    mudou_grupo_abaixo = false;

    if k > 1
        mudou_grupo_acima = Grupo_ord(k) ~= Grupo_ord(k-1);
    end
    if k < nReq
        mudou_grupo_abaixo = Grupo_ord(k) ~= Grupo_ord(k+1);
    end

    inc_local_acima  = (Inc_Acima_1(k)  == "Sim");
    inc_local_abaixo = (Inc_Abaixo_1(k) == "Sim");

    inc_amp_acima  = (Inc_Acima_3(k)  == "Sim");
    inc_amp_abaixo = (Inc_Abaixo_3(k) == "Sim");

    if (inc_local_acima && mudou_grupo_acima) || (inc_local_abaixo && mudou_grupo_abaixo)
        Leitura(k) = "Fronteira crítica";

    elseif inc_local_acima && inc_local_abaixo
        Leitura(k) = "Zona cinzenta";

    elseif inc_local_acima || inc_local_abaixo
        Leitura(k) = "Atenção local";

    elseif (inc_amp_acima || inc_amp_abaixo) && NumIncomp_ord(k) > 2
        Leitura(k) = "Alerta estrutural";

    else
        Leitura(k) = "Robusto";
    end
end

% ---------------------------------------------------------
% TABELA FINAL
% ---------------------------------------------------------
T_local = table(Req_ord(:), ID_ord(:), Rank_ord(:), Phi_ord(:), Grupo_ord(:), ...
    Inc_Acima_1(:), Inc_Abaixo_1(:), ...
    Inc_Acima_3(:), Inc_Abaixo_3(:), ...
    Qtd_Acima_3(:), Qtd_Abaixo_3(:), ...
    NumIncomp_ord(:), FlagGlobal(:), Leitura(:), ...
    'VariableNames', {'Req','ID','Rank_FPII','PhiNet','Grupo_KMeans', ...
                      'Inc_Acima_1','Inc_Abaixo_1', ...
                      'Inc_Acima_3','Inc_Abaixo_3', ...
                      'Qtd_Acima_3','Qtd_Abaixo_3', ...
                      'NumIncomp_Global','FlagGlobal','Leitura'});

% disp(' ')
% disp('--- TABELA FINAL: RANK + GRUPO + INCOMPARABILIDADE LOCAL ---')
% disp(T_local)

writetable(T_local, 'Tabela_Final_Rank_Grupo_Incomp_Local.xlsx');

%% =========================================================
% EXPORTA RESULTADOS PARA COMPARAÇÃO
%% =========================================================

ResultadosExpress.PhiNet    = phi_net;
ResultadosExpress.Rank      = rank_s2;
ResultadosExpress.Categoria = cat;
ResultadosExpress.ID        = IDs;
ResultadosExpress.Req       = req_labels;
ResultadosExpress.Pesos     = w_group_defuzz;

save('Resultados_Express.mat','ResultadosExpress');

disp(' ')
disp('Resultados Express exportados.')



%% =========================================================
% EXPORTAÇÃO AUTOMÁTICA DE TODAS AS FIGURAS EM FORMATO VETORIAL
%% =========================================================

figuras_abertas = findall(groot,'Type','figure');

% Ordena pelo número de criação da figura
[~,ord_fig] = sort([figuras_abertas.Number]);
figuras_abertas = figuras_abertas(ord_fig);

nomes_ja_utilizados = strings(0,1);

fprintf('\n');
fprintf('============================================================\n');
fprintf('EXPORTAÇÃO DAS FIGURAS VETORIAIS\n');
fprintf('============================================================\n');

for f = 1:numel(figuras_abertas)

    fig_atual = figuras_abertas(f);

    % Obtém o título principal da figura
    titulo_figura = obterTituloFigura(fig_atual);

    % Caso não exista título
    if strlength(strtrim(titulo_figura)) == 0
        titulo_figura = sprintf('Figura_%02d',f);
    end

    % Converte o título em um nome de arquivo seguro
    nome_base = sanitizarNomeArquivo(titulo_figura);

    % Evita arquivos com nomes repetidos
    nome_final = nome_base;
    contador_repeticao = 2;

    while any(strcmpi(nomes_ja_utilizados,nome_final))

        nome_final = sprintf( ...
            '%s_%02d', ...
            nome_base, ...
            contador_repeticao);

        contador_repeticao = contador_repeticao+1;

    end

    nomes_ja_utilizados(end+1,1) = string(nome_final);

    arquivo = fullfile( ...
    pasta_figuras, ...
    [nome_final '.pdf']);

exportgraphics( ...
    fig_atual, ...
    arquivo, ...
    'ContentType','vector', ...
    'BackgroundColor','white');

fprintf('Salva: %s.pdf\n',nome_final);
end

fprintf('\n%d figuras vetoriais foram salvas em:\n', ...
    numel(figuras_abertas));

fprintf('%s\n',pasta_figuras);

%% ---------------------------------------------------------
% MANTÉM SOMENTE AS TRÊS FIGURAS PRINCIPAIS ABERTAS
%% ---------------------------------------------------------

figuras_manter = [ ...
    fig_posicoes, ...
    fig_footrule, ...
    fig_classificacoes];

for f = 1:numel(figuras_abertas)

    if ~any(figuras_abertas(f) == figuras_manter)
        close(figuras_abertas(f));
    end

end

% Restaura o padrão do MATLAB para execuções posteriores
set(groot,'defaultFigureVisible','on');

fprintf('\nFiguras mantidas abertas no MATLAB:\n');
fprintf('1. Heatmap das posições no ranking\n');
fprintf('2. Spearman Footrule normalizada\n');
fprintf('3. Heatmap das classificações\n');
%% =========================================================
% FUNÇÕES AUXILIARES
%% =========================================================
function titulo = obterTituloFigura(fig)
% =========================================================
% Obtém o título principal de uma figura MATLAB.
%
% Prioridade:
%   1. sgtitle
%   2. título de um eixo
%   3. propriedade Name da figura
% =========================================================

titulo = "";

% Tenta encontrar um sgtitle
objetos_texto = findall(fig,'Type','Text');

for i = 1:numel(objetos_texto)

    try

        texto = string(objetos_texto(i).String);

        if strlength(strtrim(texto)) > 0

            % sgtitle normalmente possui Tag = 'suptitle'
            if strcmpi(objetos_texto(i).Tag,'suptitle')
                titulo = strjoin(texto," ");
                return;
            end

        end

    catch
    end

end

% Procura títulos dos eixos
eixos = findall(fig,'Type','axes');

for i = 1:numel(eixos)

    try

        texto_titulo = string(eixos(i).Title.String);

        if ~isempty(texto_titulo) && ...
                any(strlength(strtrim(texto_titulo)) > 0)

            titulo = strjoin(texto_titulo," ");
            return;

        end

    catch
    end

end

% Usa o nome da janela como alternativa
if strlength(strtrim(string(fig.Name))) > 0
    titulo = string(fig.Name);
end

end

function nome_seguro = sanitizarNomeArquivo(titulo)
% =========================================================
% Transforma o título da figura em um nome válido de arquivo.
% =========================================================

nome_seguro = char(string(titulo));

% Remove comandos simples de LaTeX
nome_seguro = regexprep(nome_seguro,'\\[a-zA-Z]+','');

% Substitui caracteres inválidos em nomes de arquivo
nome_seguro = regexprep( ...
    nome_seguro, ...
    '[<>:"/\\|?*]', ...
    '');

% Substitui espaços e pontuação por underline
nome_seguro = regexprep( ...
    nome_seguro, ...
    '[^\wÀ-ÿ-]+', ...
    '_');

% Remove repetições de underscore
nome_seguro = regexprep(nome_seguro,'_+','_');

% Remove underscores no início e no fim
nome_seguro = regexprep(nome_seguro,'^_|_$','');

% Limita o tamanho do nome
max_caracteres = 120;

if length(nome_seguro) > max_caracteres
    nome_seguro = nome_seguro(1:max_caracteres);
end

if isempty(nome_seguro)
    nome_seguro = 'Figura_sem_titulo';
end

end


function kappa = weightedCohenKappa(x, y, nClasses, tipoPeso)
% =========================================================
% WEIGHTEDCOHENKAPPA
%
% Calcula o Weighted Cohen's Kappa para duas classificações
% ordinais.
%
% Entradas:
%   x          = classificações do avaliador A
%   y          = classificações do avaliador B
%   nClasses   = número de categorias
%   tipoPeso   = 'linear' ou 'quadratic'
%
% Saída:
%   kappa      = coeficiente Kappa ponderado
%
% Para o SIPREM:
%   1 = Key
%   2 = G1
%   3 = G2
%   4 = G3
% =========================================================

    % Garante vetores-coluna
    x = x(:);
    y = y(:);

    % Remove registros inválidos ou ausentes
    validos = ...
        ~isnan(x) & ...
        ~isnan(y) & ...
        x >= 1 & x <= nClasses & ...
        y >= 1 & y <= nClasses;

    x = x(validos);
    y = y(validos);

    n = numel(x);

    if n == 0
        kappa = NaN;
        return;
    end

    %% -----------------------------------------------------
    % Matriz de contingência observada
    %% -----------------------------------------------------

    O = zeros(nClasses,nClasses);

    for r = 1:n

        classe_x = x(r);
        classe_y = y(r);

        O(classe_x,classe_y) = ...
            O(classe_x,classe_y) + 1;

    end

    % Converte contagens em proporções
    O = O/n;

    %% -----------------------------------------------------
    % Distribuições marginais
    %% -----------------------------------------------------

    marginal_x = sum(O,2);
    marginal_y = sum(O,1);

    % Concordância esperada pelo acaso
    E = marginal_x*marginal_y;

    %% -----------------------------------------------------
    % Matriz de pesos de concordância
    %% -----------------------------------------------------

    W = zeros(nClasses,nClasses);

    for i = 1:nClasses

        for j = 1:nClasses

            distancia = abs(i-j)/(nClasses-1);

            switch lower(tipoPeso)

                case 'linear'

                    W(i,j) = 1-distancia;

                case {'quadratic','quadratico','quadrática'}

                    W(i,j) = 1-distancia^2;

                otherwise

                    error([ ...
                        'Tipo de peso inválido. ', ...
                        'Use ''linear'' ou ''quadratic''.']);

            end

        end
    end

    %% -----------------------------------------------------
    % Concordâncias ponderadas
    %% -----------------------------------------------------

    concordancia_observada = sum(W.*O,'all');
    concordancia_esperada  = sum(W.*E,'all');

    denominador = 1-concordancia_esperada;

    if abs(denominador) < eps

        % Ocorre, por exemplo, quando ambas as fontes atribuem
        % exatamente uma única categoria a todos os requisitos.
        if abs(concordancia_observada-1) < 1e-12
            kappa = 1;
        else
            kappa = NaN;
        end

    else

        kappa = ...
            (concordancia_observada-concordancia_esperada) / ...
            denominador;

    end

    % Proteção contra pequenos erros numéricos
    kappa = max(-1,min(1,kappa));

end

function cat = classify_requirements_kmeans(phi_vec, key_idx)
    % -----------------------------------------------------
    % Classificação:
    %   - Key: requisitos previamente definidos
    %   - Demais: K-means em 3 grupos sobre phi_net
    %
    % Regra de rotulagem:
    %   maior centróide  -> Grupo 1
    %   centróide médio  -> Grupo 2
    %   menor centróide  -> Grupo 3
    % -----------------------------------------------------

    nReq = numel(phi_vec);
    cat = strings(nReq,1);

    key_idx = unique(key_idx(:));
    cat(key_idx) = "Key";

    idx_rest = setdiff((1:nReq)', key_idx);
    n_rest = numel(idx_rest);

    if isempty(idx_rest)
        return;
    end

    % Se houver poucos requisitos não-Key, evita erro do kmeans
    if n_rest == 1
        cat(idx_rest) = "Grupo 1";
        return;
    elseif n_rest == 2
        [~,ord2] = sort(phi_vec(idx_rest), 'descend');
        cat(idx_rest(ord2(1))) = "Grupo 1";
        cat(idx_rest(ord2(2))) = "Grupo 2";
        return;
    end

    % Número efetivo de clusters
    k = min(3, n_rest);

    % K-means sobre os fluxos líquidos dos não-Key
    phi_rest = phi_vec(idx_rest);

    % Replicates melhora estabilidade
    [idx_km, C] = kmeans(phi_rest, k, ...
        'Replicates', 20, ...
        'Start', 'plus', ...
        'Distance', 'sqeuclidean');

    % Ordena centróides do maior para o menor
    [~, ordC] = sort(C, 'descend');

    % Mapeia cluster -> grupo
    cluster_to_group = strings(k,1);
    if k >= 1, cluster_to_group(ordC(1)) = "Grupo 1"; end
    if k >= 2, cluster_to_group(ordC(2)) = "Grupo 2"; end
    if k >= 3, cluster_to_group(ordC(3)) = "Grupo 3"; end

    % Atribui grupos
    for i = 1:n_rest
        cat(idx_rest(i)) = cluster_to_group(idx_km(i));
    end
end

function code = classToCode(cat_vec)
    code = zeros(numel(cat_vec),1);

    for i = 1:numel(cat_vec)
        switch string(cat_vec(i))
            case "Key"
                code(i) = 1;
            case "Grupo 1"
                code(i) = 2;
            case "Grupo 2"
                code(i) = 3;
            case "Grupo 3"
                code(i) = 4;
            otherwise
                code(i) = NaN;
        end
    end
end
function trap = crispSaatyToTrap(val)
    % Escala trapezoidal de Mou (2004)
    if abs(val - 1) < 1e-12
        trap = [1, 1, 1, 1];
        return;
    end

    if val > 1
        v = round(val);

        if ~ismember(v, 1:9)
            error('Valor da escala Saaty fora do intervalo 1..9: %.4f', val);
        end

        if v == 9
            trap = [8, 8.5, 9, 9];
        elseif v == 1
            trap = [1, 1, 1, 1];
        else
            trap = [v-1, v-0.5, v+0.5, v+1];
        end
    else
        invv = 1 / val;
        trap_inv = crispSaatyToTrap(invv);
        trap = [1/trap_inv(4), 1/trap_inv(3), 1/trap_inv(2), 1/trap_inv(1)];
    end
end

function w = fahpBuckleyTrap(A_group)
    n = size(A_group, 1);
    r = zeros(n, 4);

    for i = 1:n
        prod_trap = [1, 1, 1, 1];
        for j = 1:n
            t = squeeze(A_group(i,j,:))';
            prod_trap = prod_trap .* t;
        end
        r(i,:) = prod_trap .^ (1/n);
    end

    sum_r = [0, 0, 0, 0];
    for i = 1:n
        sum_r = trap_add(sum_r, r(i,:));
    end

    inv_sum_r = trap_inv(sum_r);

    w = zeros(n, 4);
    for i = 1:n
        w(i,:) = trap_mul_positive(r(i,:), inv_sum_r);
    end

    wd = zeros(n,1);
    for i = 1:n
        wd(i) = defuzz_coa(w(i,:));
    end
    wd = wd / sum(wd);

    for i = 1:n
        factor = wd(i) / max(defuzz_coa(w(i,:)), eps);
        w(i,:) = w(i,:) * factor;
    end
end

function out = pref_trap(D, type, q, p)
    out = [ ...
        pref_scalar(D(1), type, q, p), ...
        pref_scalar(D(2), type, q, p), ...
        pref_scalar(D(3), type, q, p), ...
        pref_scalar(D(4), type, q, p)];
    out = sort(out);
end

function p_res = pref_scalar(d, type, q, p)

    % Garantir que d >= 0 (PROMETHEE padrão)
    d = max(0, d);

    switch type

        % =========================
        % Tipo 1: Usual
        % =========================
        case 1
            p_res = double(d > 0);

        % =========================
        % Tipo 2: U-shape
        % =========================
        case 2
            if d <= q
                p_res = 0;
            else
                p_res = 1;
            end

        % =========================
        % Tipo 3: V-shape
        % =========================
        case 3
            if d <= 0
                p_res = 0;
            elseif d <= p
                p_res = d / p;
            else
                p_res = 1;
            end

        % =========================
        % Tipo 4: Level (como você tinha)
        % =========================
        case 4
            if d <= q
                p_res = 0;
            elseif d <= p
                p_res = 0.5;
            else
                p_res = 1;
            end

        % =========================
        % Tipo 5: Linear (V-shape com indiferença)
        % =========================
        case 5
            if d <= q
                p_res = 0;
            elseif d <= p
                p_res = (d - q) / (p - q);
            else
                p_res = 1;
            end

        % =========================
        % Tipo 6: Gaussian
        % =========================
        case 6
            if d <= 0
                p_res = 0;
            else
                sigma = p / 3; % regra comum
                p_res = 1 - exp(-(d^2) / (2 * sigma^2));
            end

        otherwise
            error('Tipo de preferência não implementado.');

    end
end
function C = trap_add(A, B)
    C = [A(1)+B(1), A(2)+B(2), A(3)+B(3), A(4)+B(4)];
end

function C = trap_sub(A, B)
    C = [A(1)-B(4), A(2)-B(3), A(3)-B(2), A(4)-B(1)];
end

function C = trap_scalar_div(A, s)
    C = A / s;
end

function invA = trap_inv(A)
    if any(A <= 0)
        error('trap_inv requer trapézio estritamente positivo.');
    end
    invA = [1/A(4), 1/A(3), 1/A(2), 1/A(1)];
end

function C = trap_mul_positive(A, B)
    C = [A(1)*B(1), A(2)*B(2), A(3)*B(3), A(4)*B(4)];
end

function C = trap_mul_geldermann(A, B)
    ml1 = A(2); mu1 = A(3); alpha1 = A(2)-A(1); beta1 = A(4)-A(3);
    ml2 = B(2); mu2 = B(3); alpha2 = B(2)-B(1); beta2 = B(4)-B(3);

    ml = ml1 * ml2;
    mu = mu1 * mu2;
    alpha = ml1 * alpha2 + ml2 * alpha1 - alpha1 * alpha2;
    beta  = mu1 * beta2  + mu2 * beta1  + beta1 * beta2;

    alpha = max(alpha, 0);
    beta  = max(beta, 0);

    C = [ml - alpha, ml, mu, mu + beta];
    C(C < 0) = 0;
    C = sort(C);
end

function x = defuzz_coa(T)
    a = T(1); b = T(2); c = T(3); d = T(4);

    if abs(d - a) < 1e-12
        x = b;
        return;
    end

    den = 3 * (c + d - a - b);
    if abs(den) < 1e-12
        x = mean(T);
        return;
    end

    x = ((c+d)^2 - c*d - (a+b)^2 + a*b) / den;
end

function [Phi_plus, Phi_minus, phi_net, Phi_plus_fuzzy, Phi_minus_fuzzy, Phi_net_fuzzy] = ...
    runFuzzyPrometheeTrap(F, w_fuzzy, critDir, pref_types, q_vals, p_vals)

    nReq = size(F, 1);
    nCrit = size(F, 2);

    PI = zeros(nReq, nReq, 4);

    for i = 1:nReq
        for j = 1:nReq
            if i == j
                continue;
            end

            pi_ij = [0, 0, 0, 0];

            for k = 1:nCrit
                Ai = squeeze(F(i,k,:))';
                Bj = squeeze(F(j,k,:))';

                if critDir(k) == 1
                    D = trap_sub(Ai, Bj);
                else
                    D = trap_sub(Bj, Ai);
                end

                Pk = pref_trap(D, pref_types(k), q_vals(k), p_vals(k));
                Wk = squeeze(w_fuzzy(k,:))';

                term = trap_mul_geldermann(Wk, Pk);
                pi_ij = trap_add(pi_ij, term);
            end

            PI(i,j,:) = pi_ij;
        end
    end

    Phi_plus_fuzzy  = zeros(nReq, 4);
    Phi_minus_fuzzy = zeros(nReq, 4);
    Phi_net_fuzzy   = zeros(nReq, 4);

    Phi_plus  = zeros(nReq, 1);
    Phi_minus = zeros(nReq, 1);
    phi_net   = zeros(nReq, 1);

    for i = 1:nReq
        sumP = [0, 0, 0, 0];
        sumM = [0, 0, 0, 0];

        for j = 1:nReq
            if i == j
                continue;
            end
            sumP = trap_add(sumP, squeeze(PI(i,j,:))');
            sumM = trap_add(sumM, squeeze(PI(j,i,:))');
        end

        avgP = trap_scalar_div(sumP, (nReq - 1));
        avgM = trap_scalar_div(sumM, (nReq - 1));
        netF = trap_sub(avgP, avgM);

        Phi_plus_fuzzy(i,:)  = avgP;
        Phi_minus_fuzzy(i,:) = avgM;
        Phi_net_fuzzy(i,:)   = netF;

        Phi_plus(i)  = defuzz_coa(avgP);
        Phi_minus(i) = defuzz_coa(avgM);
        phi_net(i)   = defuzz_coa(netF);
    end
end
function Phi_uni = computeUnicriterionNetFlows(F, w_ref, critDir, pref_types, q_vals, p_vals)
    % Calcula os fluxos líquidos unicritério usados no GAIA-PROMETHEE
    %
    % Entradas:
    %   F         : matriz fuzzy das alternativas [nReq x nCrit x 4]
    %   w_ref     : pesos de referência (não entram no fluxo unicritério,
    %               mas mantidos por compatibilidade futura)
    %   critDir   : direção dos critérios
    %   pref_types: tipo de função de preferência
    %   q_vals    : limiares de indiferença
    %   p_vals    : limiares de preferência
    %
    % Saída:
    %   Phi_uni   : matriz [nReq x nCrit] de fluxos líquidos unicritério

    nReq  = size(F,1);
    nCrit = size(F,2);

    Phi_uni = zeros(nReq, nCrit);

    for k = 1:nCrit
        PI_k = zeros(nReq, nReq, 4);

        for i = 1:nReq
            for j = 1:nReq
                if i == j
                    continue;
                end

                Ai = squeeze(F(i,k,:))';
                Bj = squeeze(F(j,k,:))';

                if critDir(k) == 1
                    D = trap_sub(Ai, Bj);
                else
                    D = trap_sub(Bj, Ai);
                end

                Pk = pref_trap(D, pref_types(k), q_vals(k), p_vals(k));
                PI_k(i,j,:) = Pk;   % sem peso: fluxo unicritério puro
            end
        end

        for i = 1:nReq
            sumP = [0 0 0 0];
            sumM = [0 0 0 0];

            for j = 1:nReq
                if i == j
                    continue;
                end
                sumP = trap_add(sumP, squeeze(PI_k(i,j,:))');
                sumM = trap_add(sumM, squeeze(PI_k(j,i,:))');
            end

            avgP = trap_scalar_div(sumP, (nReq - 1));
            avgM = trap_scalar_div(sumM, (nReq - 1));
            netF = trap_sub(avgP, avgM);

            Phi_uni(i,k) = defuzz_coa(netF);
        end
    end
end

function [idx_km_full, C_sorted, group_names] = get_kmeans_groups(phi_vec, key_idx)
    % Retorna a alocação K-means apenas para auditoria
    nReq = numel(phi_vec);
    idx_km_full = nan(nReq,1);

    key_idx = unique(key_idx(:));
    idx_rest = setdiff((1:nReq)', key_idx);
    n_rest = numel(idx_rest);

    if n_rest < 3
        C_sorted = [];
        group_names = strings(0,1);
        return;
    end

    phi_rest = phi_vec(idx_rest);

    [idx_km, C] = kmeans(phi_rest, 3, ...
        'Replicates', 20, ...
        'Start', 'plus', ...
        'Distance', 'sqeuclidean');

    [C_sorted, ordC] = sort(C, 'descend');

    group_names = strings(3,1);
    group_names(1) = "Grupo 1";
    group_names(2) = "Grupo 2";
    group_names(3) = "Grupo 3";

    idx_km_full(idx_rest) = idx_km;
end

function trap = fuzzifyByScale(val, scale_max, TFN_eval_5, TFN_eval_7, TFN_eval_9)

    % arredonda para o valor mais próximo da escala
    v = round(val);

    % satura dentro dos limites válidos
    v = max(1, min(scale_max, v));

    switch scale_max
        case 5
            trap = TFN_eval_5(v,:);

        case 7
            trap = TFN_eval_7(v,:);

        case 9
            trap = TFN_eval_9(v,:);

        otherwise
            error('Escala não suportada.');
    end
end

function val = linguistic2num(x)

    % 1. Se vazio ou missing → erro claro
    if isempty(x) || (isstring(x) && ismissing(x))
        error('Valor vazio ou missing encontrado na planilha');
    end

    % 2. Se for numérico
    if isnumeric(x)
        if isnan(x)
            error('Valor NaN encontrado na planilha');
        end
        val = x;
        return;
    end

    % 3. Converter para string limpa
    str = lower(strtrim(string(x)));

    % Se virou missing depois da conversão
    if ismissing(str)
        error('Valor inválido (missing) encontrado');
    end

    str = char(str);

    % 4. Mapear
    if strcmp(str, 'muito alto')
        val = 7;
    elseif strcmp(str, 'alto')
        val = 6;
    elseif strcmp(str, 'moderadamente alto')
        val = 5;
    elseif strcmp(str, 'médio') || strcmp(str, 'medio')
        val = 4;
    elseif strcmp(str, 'moderadamente baixo')
        val = 3;
    elseif strcmp(str, 'baixo')
        val = 2;
    elseif strcmp(str, 'muito baixo')
        val = 1;
    else
        error('Valor linguístico desconhecido: %s', str)
    end

end


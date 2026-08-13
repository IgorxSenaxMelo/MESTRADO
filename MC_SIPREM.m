clc; clear all; close all;

%% PASTA DE SAÍDA DAS FIGURAS
tic
pasta_figuras = fullfile(pwd, 'Figuras_MC_PDF');

if ~exist(pasta_figuras, 'dir')
    mkdir(pasta_figuras);
end

%% CONFIGURAÇÕES
N_mc = 100; % Elevado para 1000 iterações conforme validação estatística
rng(42);

input_file = 'dados_requisitos_lista.xlsx';
all_sheets = sheetnames(input_file);
all_sheets = all_sheets(1:end-1); % IGNORA ÚLTIMA
nExperts = numel(all_sheets);
nCrit = 5;

%% LEITURA DA BASE DO FAHP EXPRESS COLETIVO (S2)
input_fahp_file = 'F_AHP_A.xlsx'; % Atualizado para o seu arquivo F_AHP_A.xlsx
[~, sheets_fahp] = xlsfinfo(input_fahp_file);
abas_fahp = sheets_fahp(1:end-1);
nExperts_fahp = length(abas_fahp);

% Matriz para armazenar as linhas de referência numéricas de cada especialista [nExperts x nCrit]
linhas_ref_all = zeros(nExperts_fahp, nCrit);
for s = 1:nExperts_fahp
    linha_txt = readcell(input_fahp_file, 'Sheet', abas_fahp{s}, 'Range', 'B4:F4');
    for k = 1:nCrit
        linhas_ref_all(s, k) = saaty_linguistic2num(linha_txt{k});
    end
end

% Coleta os pesos e informações individuais do S2 determinístico usando sua função
[w_fuzzy_group, w_group_defuzz, info_s2] = get_ws1_fuzzy_from_fahp_express(input_fahp_file);

crit_names = {'Impacto', 'Custo', 'CAPACIDADE NACIONAL DE IMPLEMENTAÇÃO', 'Prazo', 'RiscoVerif'};
critDir = [1, -1, 1, -1, -1];
pref_types = [1, 4, 4, 4, 4];
scale_max = [7, 7, 7, 7, 7];
scale_min = [1, 1, 1, 1, 1];
A_scale = scale_max - scale_min;
q_base = [0, 0.06*A_scale(2), 0.06*A_scale(3), 0.06*A_scale(4), 0.06*A_scale(5)];
p_base = [0, 0.21*A_scale(2), 0.21*A_scale(3), 0.21*A_scale(4), 0.21*A_scale(5)];

% Escalas Trapezoidais fiéis ao seu modelo
TFN_eval_5 = [1.0 1.0 1.5 2.0; 1.5 2.0 2.0 2.5; 2.0 2.5 3.0 3.5; 3.0 3.5 4.0 4.5; 4.0 4.5 5.0 5.0];
TFN_eval_7 = [1.0 1.0 1.5 2.0; 1.0 1.5 2.5 3.0; 2.0 2.5 3.5 4.0; 3.0 3.5 4.5 5.0; 4.0 4.5 5.5 6.0; 5.0 5.5 6.5 7.0; 6.0 6.5 7.0 7.0];
TFN_eval_9 = [1.0 1.0 1.5 2.0; 1.0 1.5 2.5 3.0; 2.0 2.5 3.5 4.0; 3.0 3.5 4.5 5.0; 4.0 4.5 5.0 5.5; 5.0 5.5 6.5 7.0; 6.0 6.5 7.5 8.0; 7.0 7.5 8.5 9.0; 8.0 8.5 9.0 9.0];

%% LEITURA E ARMAZENAMENTO DAS AVALIAÇÕES DOS REQUISITOS (INDIVIDUAL)
T0 = readtable(input_file, 'Sheet', all_sheets{1}, 'VariableNamingRule', 'preserve');
IDs = T0{:,1};
[nReq, ~] = size(T0);
req_labels = arrayfun(@(x) sprintf('R%d', x), 1:nReq, 'UniformOutput', false);

data_all = zeros(nReq, nCrit, nExperts);
for e = 1:nExperts
    Te = readtable(input_file, 'Sheet', all_sheets{e}, 'VariableNamingRule', 'preserve');
    data_raw = Te{:, 3:(2+nCrit)};
    for i = 1:nReq
        for k = 1:nCrit
            data_all(i,k,e) = linguistic2num(data_raw{i,k});
        end
    end
end

%% CÁLCULO DO CENÁRIO BASE DETERMINÍSTICO PURO S2 (Fiel ao  SIPREM)
phi_net_experts_base = zeros(nReq, nExperts);
for e = 1:nExperts
    F_e = zeros(nReq, nCrit, 4);
    for i = 1:nReq
        for k = 1:nCrit
            F_e(i,k,:) = fuzzifyByScale(data_all(i,k,e), scale_max(k), TFN_eval_5, TFN_eval_7, TFN_eval_9);
        end
    end
    w_fuzzy_e = squeeze(info_s2.w_fuzzy_individual(:,:,e));
    [~, ~, phi_net_e, ~, ~, ~] = runFuzzyPrometheeTrap(F_e, w_fuzzy_e, critDir, pref_types, q_base, p_base);
    phi_net_experts_base(:,e) = phi_net_e;
end
phi_net_base_s2 = mean(phi_net_experts_base, 2);
rank_base = nReq + 1 - tiedrank(phi_net_base_s2);

% Lógica de Key por maioria para categorias
impacto_ind = squeeze(data_all(:,1,:));
prob_key_req = sum(impacto_ind == scale_max(1), 2) / nExperts;

%% PRÉ-ALOCAÇÃO MONTE CARLO
phi_mc = zeros(nReq, N_mc);
rank_mc = zeros(nReq, N_mc);
% Fluxos PROMETHEE I por iteração
phi_plus_mc  = zeros(nReq,N_mc);
phi_minus_mc = zeros(nReq,N_mc);
top1_count = zeros(nReq,1);
cat_mc = zeros(nReq, N_mc);   
W_samples = zeros(N_mc, nCrit);

%% LOOP MONTE CARLO TOTALMENTE ALINHADO AO S2
for mc = 1:N_mc
    %% 1. AMOSTRAGEM DOS PESOS (FAHP EXPRESS VIA BUCKLEY POR RODADA)
    linha_ref_mc = zeros(1, nCrit);
    for k = 1:nCrit
        vals_julg = linhas_ref_all(:, k);
        uvals_julg = unique(vals_julg);
        prob_julg = zeros(size(uvals_julg));
        for kk = 1:length(uvals_julg)
            prob_julg(kk) = sum(vals_julg == uvals_julg(kk));
        end
        prob_julg = prob_julg / sum(prob_julg);
        idx_julg = randsample(length(uvals_julg), 1, true, prob_julg);
        linha_ref_mc(k) = uvals_julg(idx_julg);
    end
    
    A_mc = zeros(nCrit, nCrit);
    for i = 1:nCrit
        for j = 1:nCrit
            A_mc(i,j) = linha_ref_mc(j) / linha_ref_mc(i);
        end
    end
    
    m_fuzzy_mc = zeros(nCrit, nCrit, 4);
    for i = 1:nCrit
        for j = 1:nCrit
            m_fuzzy_mc(i,j,:) = crisp_to_fuzzy_trap_interp(A_mc(i,j));
        end
    end

    % Auditoria automática da reciprocidade fuzzy na iteração MC
    tol_rec = 1e-10;
    for i = 1:nCrit
        for j = i+1:nCrit
            tij = squeeze(m_fuzzy_mc(i,j,:))';
            tji = squeeze(m_fuzzy_mc(j,i,:))';

            esperado = [ ...
                1/tij(4), ...
                1/tij(3), ...
                1/tij(2), ...
                1/tij(1)];

            if max(abs(tji - esperado)) > tol_rec
                error('Falha de reciprocidade fuzzy no MC em (%d,%d).', i, j);
            end
        end
    end
    [w_crisp_mc_iter, w_fuzzy_mc_iter] = calc_fahp_buckley(m_fuzzy_mc);
    W_samples(mc, :) = w_crisp_mc_iter(:)'; 
    
    %% 2. AMOSTRAGEM DOS ATRIBUTOS POR ESPECIALISTA (ABORDAGEM DE GRUPO S2)
    phi_plus_experts_mc  = zeros(nReq,nExperts);
phi_minus_experts_mc = zeros(nReq,nExperts);
phi_net_experts_mc   = zeros(nReq,nExperts);
    for e = 1:nExperts
        F_e_mc = zeros(nReq, nCrit, 4);
        for r = 1:nReq
            for c = 1:nCrit
                vals = squeeze(data_all(r,c,:));
                uvals = unique(vals);
                prob = zeros(size(uvals));
                for kk = 1:length(uvals)
                    prob(kk) = sum(vals == uvals(kk));
                end
                prob = prob / sum(prob);
                idx = randsample(length(uvals), 1, true, prob);
                
                F_e_mc(r,c,:) = fuzzifyByScale(uvals(idx), scale_max(c), TFN_eval_5, TFN_eval_7, TFN_eval_9);
            end
        end
        
        % Roda o PROMETHEE Individual da iteração
        [phi_plus_e_mc, ...
 phi_minus_e_mc, ...
 phi_net_e_mc, ...
 ~, ~, ~] = runFuzzyPrometheeTrap( ...
                F_e_mc, ...
                w_fuzzy_mc_iter, ...
                critDir, ...
                pref_types, ...
                q_base, ...
                p_base);

phi_plus_experts_mc(:,e)  = phi_plus_e_mc;
phi_minus_experts_mc(:,e) = phi_minus_e_mc;
phi_net_experts_mc(:,e)   = phi_net_e_mc;
    end
    
   %% 3. AGREGAÇÃO POSTERIOR DA ITERAÇÃO

% Fluxos coletivos médios da iteração
phi_plus_now  = mean(phi_plus_experts_mc,2);
phi_minus_now = mean(phi_minus_experts_mc,2);
phi_now       = mean(phi_net_experts_mc,2);

% Ranking completo PROMETHEE II
rank_now = nReq + 1 - tiedrank(phi_now);

% Armazenamento
phi_plus_mc(:,mc)  = phi_plus_now;
phi_minus_mc(:,mc) = phi_minus_now;
phi_mc(:,mc)       = phi_now;
rank_mc(:,mc)      = rank_now;
    
    % Categorização e contagem de Top1
    is_key_mc = rand(nReq,1) < prob_key_req;
    key_idx_mc = find(is_key_mc);
    cat_now = classify_requirements_kmeans(phi_now, key_idx_mc);
    cat_mc(:,mc) = classToCode(cat_now);
    
    idx_top = find(rank_now == 1);
    top1_count(idx_top) = top1_count(idx_top) + 1;
end

%% =========================================================
% OUTRANKING ACCEPTABILITY MATRIX – PROMETHEE I
% ==========================================================

% outranking_acceptability(i,j):
% porcentagem de iterações em que Ri sobreclassifica Rj

outranking_acceptability = zeros(nReq,nReq);

% Tolerância numérica para evitar diferenças artificiais
tol_prom1 = 1e-10;

for mc = 1:N_mc

    phi_plus_now  = phi_plus_mc(:,mc);
    phi_minus_now = phi_minus_mc(:,mc);

    for i = 1:nReq
        for j = 1:nReq

            if i == j
                continue;
            end

            % Condições PROMETHEE I:
            % i não é pior no fluxo positivo;
            % i não é pior no fluxo negativo;
            % i é estritamente melhor em pelo menos um fluxo.

            nao_pior_positivo = ...
                phi_plus_now(i) >= phi_plus_now(j) - tol_prom1;

            nao_pior_negativo = ...
                phi_minus_now(i) <= phi_minus_now(j) + tol_prom1;

            estritamente_melhor = ...
                phi_plus_now(i) > phi_plus_now(j) + tol_prom1 || ...
                phi_minus_now(i) < phi_minus_now(j) - tol_prom1;

            if nao_pior_positivo && ...
               nao_pior_negativo && ...
               estritamente_melhor

                outranking_acceptability(i,j) = ...
                    outranking_acceptability(i,j) + 1;
            end
        end
    end
end

% Quantidade média de alternativas sobreclassificadas
dominance_score = ...
    sum(outranking_acceptability,2) / 100;

[~,ordem_outranking] = sort( ...
    dominance_score, ...
    'descend');

M_out = outranking_acceptability( ...
    ordem_outranking, ...
    ordem_outranking);

labels_out = req_labels(ordem_outranking);

% Conversão para porcentagem
outranking_acceptability = ...
    100 * outranking_acceptability / N_mc;

%% RESULTADOS E EXPORTAÇÃO
mean_rank = mean(rank_mc, 2);
std_rank  = std(rank_mc, 0, 2);
freq_top1 = top1_count / N_mc;
mean_phi  = mean(phi_mc, 2);
std_phi   = std(phi_mc, 0, 2);
T_mc = table(req_labels(:), IDs, rank_base(:), mean_rank, std_rank, freq_top1, mean_phi, std_phi, ...
    'VariableNames', {'Req','ID','Rank_Base_S2','MeanRank_MC','StdRank_MC','FreqTop1_MC','MeanPhi_MC','StdPhi_MC'});
T_mc = sortrows(T_mc, 'MeanRank_MC', 'ascend');
disp('--- RESULTADOS MONTE CARLO (ALINHADO AO CENÁRIO S2) ---');
disp(T_mc);
writetable(T_mc, 'MonteCarlo_S2_Resumo_Fiel.xlsx');

%% =========================================================
% TABELA DE PROBABILIDADE DE CATEGORIZAÇÃO EM CASCATA
%% =========================================================
freq_key = sum(cat_mc == 1, 2); freq_g1 = sum(cat_mc == 2, 2); freq_g2 = sum(cat_mc == 3, 2); freq_g3 = sum(cat_mc == 4, 2);
pct_key = (freq_key / N_mc) * 100; pct_g1 = (freq_g1 / N_mc) * 100; pct_g2 = (freq_g2 / N_mc) * 100; pct_g3 = (freq_g3 / N_mc) * 100;

T_categorias = table(req_labels(:), IDs, pct_key, pct_g1, pct_g2, pct_g3, ...
    'VariableNames', {'Req', 'ID', 'Pct_Key', 'Pct_Grupo1', 'Pct_Grupo2', 'Pct_Grupo3'});
T_categorias = sortrows(T_categorias, {'Pct_Key', 'Pct_Grupo1', 'Pct_Grupo2'}, {'descend', 'descend', 'descend'});
writetable(T_categorias, 'MonteCarlo_Estabilidade_Categorias.xlsx');

%% =========================================================
% GRÁFICO – PROBABILIDADE DE CLASSIFICAÇÃO POR REQUISITO
% ==========================================================

% Matriz:
% linhas  = requisitos
% colunas = Key, Grupo 1, Grupo 2 e Grupo 3
pct_classificacao = [pct_key, pct_g1, pct_g2, pct_g3];

% Ordenação em cascata:
% maior probabilidade de Key;
% depois maior probabilidade de G1;
% depois maior probabilidade de G2.
[~, ordem_classificacao] = sortrows( ...
    [-pct_key, -pct_g1, -pct_g2, -pct_g3], ...
    [1 2 3 4]);

pct_class_plot = pct_classificacao(ordem_classificacao,:);
labels_class_plot = req_labels(ordem_classificacao);

% Criação da figura
figure( ...
    'Color','w', ...
    'Name','Probabilidade_Classificacao_Requisitos', ...
    'Position',[100 50 1200 850]);

% Barras horizontais empilhadas
barh(pct_class_plot, 'stacked');
% Valores percentuais no interior das barras
limiar_texto = 4; % Mostra apenas probabilidades >= 4%

for i = 1:nReq

    acumulado = 0;

    for g = 1:4

        valor = pct_class_plot(i,g);

        if valor >= limiar_texto

            posicao_x = acumulado + valor/2;

            text( ...
                posicao_x, ...
                i, ...
                sprintf('%.0f%%', valor), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontSize',8, ...
                'FontWeight','bold');

        end

        acumulado = acumulado + valor;

    end
end

% Configuração dos eixos
yticks(1:nReq);
yticklabels(labels_class_plot);

set(gca, ...
    'YDir','reverse', ...
    'FontSize',9, ...
    'TickLength',[0 0]);

xlabel('Probabilidade de classificação (%)');
ylabel('Requisito');

title({ ...
    'Probabilidade de classificação por requisito', ...
    sprintf('Monte Carlo – %d iterações', N_mc)});

legend( ...
    {'Key','Grupo 1','Grupo 2','Grupo 3'}, ...
    'Location','southoutside', ...
    'Orientation','horizontal');

xlim([0 100]);
xticks(0:10:100);

grid on;
box on;

%% =========================================================
% PLOTAGEM DOS GRÁFICOS ATUALIZADOS
%% =========================================================
labels = req_labels; phi_all = phi_mc; phi_std = std(phi_all, 0, 2); rank_det = rank_base(:); rank_mc_plot = mean(rank_mc, 2);
rho = corr(rank_det, rank_mc_plot, 'Type', 'Spearman');
prob_key = freq_key / N_mc; 

% GRÁFICO 4 – BUMP CHART OTIMIZADO (ALTA DISPERSÃO DE TEXTO)
figure('Color', 'w', 'Position', [100, 100, 1000, 700]); hold on;
limiar_mudanca = 2.0; mudou_significativo = abs(rank_det - rank_mc_plot) >= limiar_mudanca;
cores_map = lines(nReq);

for i = 1:nReq
    if ~mudou_significativo(i)
        plot([1, 2], [rank_det(i), rank_mc_plot(i)], ':', 'LineWidth', 1.1, 'Marker', 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.75 0.75 0.75], 'Color', [0.75 0.75 0.75]);
    end
end
for i = 1:nReq
    if mudou_significativo(i)
        plot([1, 2], [rank_det(i), rank_mc_plot(i)], '-', 'LineWidth', 2.5, 'Marker', 'o', 'MarkerSize', 8, 'MarkerFaceColor', cores_map(i,:), 'Color', cores_map(i,:));
    end
end

rank_det_ajustado = rank_det; rank_mc_ajustado = rank_mc_plot; dist_minima = 0.48;
[~, idx_sort_det] = sort(rank_det_ajustado);
for i = 2:nReq
    curr = idx_sort_det(i); prev = idx_sort_det(i-1);
    if (rank_det_ajustado(curr) - rank_det_ajustado(prev)) < dist_minima, rank_det_ajustado(curr) = rank_det_ajustado(prev) + dist_minima; end
end
[~, idx_sort_mc] = sort(rank_mc_ajustado);
for i = 2:nReq
    curr = idx_sort_mc(i); prev = idx_sort_mc(i-1);
    if (rank_mc_ajustado(curr) - rank_mc_ajustado(prev)) < dist_minima, rank_mc_ajustado(curr) = rank_mc_ajustado(prev) + dist_minima; end
end

for i = 1:nReq
    if mudou_significativo(i), fw = 'bold'; fs = 10; else, fw = 'normal'; fs = 9; end
    text(0.91, rank_det_ajustado(i), labels{i}, 'HorizontalAlignment', 'right', 'FontWeight', fw, 'FontSize', fs);
    text(2.09, rank_mc_ajustado(i), labels{i}, 'HorizontalAlignment', 'left', 'FontWeight', fw, 'FontSize', fs);
end
set(gca, 'YDir', 'reverse', 'XLim', [0.1, 2.9], 'YLim', [0.5, max([rank_det_ajustado; rank_mc_ajustado]) + 0.5], 'XTick', [1 2], 'XTickLabel', {'Determinístico (S2)', 'Estocástico S2 (médio)'}, 'FontSize', 11, 'FontName', 'Helvetica');
title(['Sensibilidade Global do Ranking S2 (Spearman \rho = ' num2str(rho,3) ')'], 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Posição (Ranking)', 'FontSize', 12); grid on; box on; hold off;

%% =========================================================
% HEATMAP MELHORADO – OUTRANKING ACCEPTABILITY PROMETHEE I
% ==========================================================

% Ordenação por força média de sobreclassificação
dominance_score = sum(outranking_acceptability,2);

[~,ordem_outranking] = sort(dominance_score,'descend');

M_out = outranking_acceptability( ...
    ordem_outranking, ...
    ordem_outranking);

labels_out = req_labels(ordem_outranking);

% Coloca NaN na diagonal para destacá-la
for i = 1:nReq
    M_out(i,i) = NaN;
end

figure( ...
    'Color','w', ...
    'Name','Outranking_Acceptability_PROMETHEE_I', ...
    'Position',[50 40 1250 950]);

ax = axes;

imagesc(ax,M_out);

% Fundo para células NaN
set(ax,'Color',[0.92 0.92 0.92]);

% Paleta mais adequada
colormap(ax,parula);

% Escala completa
clim(ax,[0 100]);

cb = colorbar;
cb.Label.String = ...
    'Probabilidade de sobreclassificação (%)';
cb.FontSize = 10;

axis square;

xlabel('Requisito sobreclassificado');
ylabel('Requisito que sobreclassifica');

title({ ...
    'Matriz de aceitabilidade de sobreclassificação – PROMETHEE I', ...
    sprintf('Monte Carlo – %d iterações',N_mc)});

xticks(1:nReq);
xticklabels(labels_out);
xtickangle(90);

yticks(1:nReq);
yticklabels(labels_out);

set(gca, ...
    'FontSize',8, ...
    'TickLength',[0 0], ...
    'YDir','normal');

% Exibe apenas probabilidades relevantes
limiar_texto_out = 50;

for i = 1:nReq
    for j = 1:nReq

        valor = M_out(i,j);

        if isnan(valor)
            continue;
        end

        if valor >= limiar_texto_out

            if valor >= 70
                cor_texto = 'white';
            else
                cor_texto = 'black';
            end

            text( ...
                j,i, ...
                sprintf('%.0f%%',valor), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontSize',6, ...
                'FontWeight','bold', ...
                'Color',cor_texto);
        end
    end
end

box on;


%% ============================================================
% SENSIBILIDADE GLOBAL:
% PESO DOS CRITÉRIOS × ALTERAÇÃO DO RANKING
% =============================================================

% rank_mc:
% linhas   = requisitos
% colunas  = iterações Monte Carlo
%
% rank_base:
% ranking determinístico S2, vetor nReq × 1

% Distância média absoluta do ranking em cada iteração
rank_deviation_iter = mean( ...
    abs(rank_mc - rank_base(:)), ...
    1, ...
    'omitnan');

% Correlação entre o peso de cada critério e a alteração do ranking
sens_rank = zeros(1,nCrit);
pvalue_rank = zeros(1,nCrit);

for j = 1:nCrit

    [sens_rank(j), pvalue_rank(j)] = corr( ...
        W_samples(:,j), ...
        rank_deviation_iter', ...
        'Type','Spearman', ...
        'Rows','complete');

end

% Gráfico
figure;

bar(sens_rank);

yline(0,'k-');

xticks(1:nCrit);
xticklabels(crit_names);
xtickangle(30);

ylabel('Correlação de Spearman');
title({'Sensibilidade Global do Ranking', ...
       'Peso do critério × desvio médio das posições'});

grid on;
box on;

% Inserção dos valores sobre as barras
for j = 1:nCrit

    if sens_rank(j) >= 0
        deslocamento = 0.02;
        alinhamento = 'bottom';
    else
        deslocamento = -0.02;
        alinhamento = 'top';
    end

    text(j, ...
         sens_rank(j) + deslocamento, ...
         sprintf('%.2f',sens_rank(j)), ...
         'HorizontalAlignment','center', ...
         'VerticalAlignment',alinhamento);

end



%% =========================================================
% CONVERGÊNCIA DAS PROBABILIDADES DE CLASSIFICAÇÃO – R11
% ==========================================================

req_conv = 19;
iteracoes = 1:N_mc;

% Probabilidades acumuladas
prob_key_acum = 100 * cumsum(cat_mc(req_conv,:) == 1) ./ iteracoes;
prob_g1_acum  = 100 * cumsum(cat_mc(req_conv,:) == 2) ./ iteracoes;
prob_g2_acum  = 100 * cumsum(cat_mc(req_conv,:) == 3) ./ iteracoes;
prob_g3_acum  = 100 * cumsum(cat_mc(req_conv,:) == 4) ./ iteracoes;

% Probabilidades finais
prob_key_final = prob_key_acum(end);
prob_g1_final  = prob_g1_acum(end);
prob_g2_final  = prob_g2_acum(end);
prob_g3_final  = prob_g3_acum(end);

% Pontos mostrados no gráfico
idx_plot = unique(round( ...
    linspace(10,N_mc,min(100,N_mc))));

figure( ...
    'Color','w', ...
    'Name',['Convergencia_Probabilidades_' req_labels{req_conv}], ...
    'Position',[100 100 1100 650]);

plot(idx_plot,prob_key_acum(idx_plot), ...
    'LineWidth',2);

hold on;

plot(idx_plot,prob_g1_acum(idx_plot), ...
    'LineWidth',2);

plot(idx_plot,prob_g2_acum(idx_plot), ...
    'LineWidth',2);

plot(idx_plot,prob_g3_acum(idx_plot), ...
    'LineWidth',2);

% Linhas horizontais com os valores finais
yline(prob_key_final,'--', ...
    sprintf('Key final = %.1f%%',prob_key_final), ...
    'HandleVisibility','off');

yline(prob_g1_final,'--', ...
    sprintf('G1 final = %.1f%%',prob_g1_final), ...
    'HandleVisibility','off');

yline(prob_g2_final,'--', ...
    sprintf('G2 final = %.1f%%',prob_g2_final), ...
    'HandleVisibility','off');

yline(prob_g3_final,'--', ...
    sprintf('G3 final = %.1f%%',prob_g3_final), ...
    'HandleVisibility','off');

xlabel('Número acumulado de simulações');
ylabel('Probabilidade acumulada (%)');

title({ ...
    ['Estabilização das probabilidades de ' req_labels{req_conv}], ...
    sprintf('Monte Carlo – %d iterações',N_mc)});

legend( ...
    {'Key','Grupo 1','Grupo 2','Grupo 3'}, ...
    'Location','eastoutside');

xlim([idx_plot(1) N_mc]);
ylim([0 100]);

grid on;
box on;
hold off;

%% =========================================================
% CONVERGÊNCIA DO MONTE CARLO
% Erro padrão de φnet
% ==========================================================

passo = max(10,round(N_mc/50));

n_sim = passo:passo:N_mc;

sem_medio = zeros(size(n_sim));
sem_max   = zeros(size(n_sim));

for k = 1:length(n_sim)

    n = n_sim(k);

    % erro padrão de cada requisito
    sem = std(phi_mc(:,1:n),0,2)./sqrt(n);

    sem_medio(k) = mean(sem);
    sem_max(k)   = max(sem);

end
figure( ...
    'Color','w',...
    'Name','Convergencia_SEM_phi_net',...
    'Position',[100 100 950 600]);

plot(n_sim,sem_medio,...
    '-o',...
    'LineWidth',2,...
    'MarkerFaceColor','w');

hold on;

plot(n_sim,sem_max,...
    '-s',...
    'LineWidth',2,...
    'MarkerFaceColor','w');

xlabel('Número de simulações');

ylabel('Erro padrão de \phi_{net}');

title('Convergência do erro padrão de \phi_{net}');

legend({'SEM médio','SEM máximo'},...
    'Location','northeast');

grid on;
box on;
%% =========================================================
% ROLLING STABILITY - KEY
% ==========================================================

janela = 20;
passo  = 10;

inicio = 1:passo:(N_mc-2*janela+1);

rho_key = zeros(length(inicio),1);
x_roll  = zeros(length(inicio),1);

for k = 1:length(inicio)

    i1 = inicio(k);
    i2 = i1 + janela - 1;

    j1 = i2 + 1;
    j2 = j1 + janela - 1;

    % Probabilidade de Key em cada janela
    pA = mean(cat_mc(:,i1:i2)==1,2);
    pB = mean(cat_mc(:,j1:j2)==1,2);

    rho_key(k) = corr(pA,pB,'Type','Spearman');

    x_roll(k) = (j1+j2)/2;

end

%% =========================================================
% ROLLING STABILITY - GRUPO 1
% ==========================================================

rho_g1 = zeros(length(inicio),1);

for k = 1:length(inicio)

    i1 = inicio(k);
    i2 = i1 + janela - 1;

    j1 = i2 + 1;
    j2 = j1 + janela - 1;

    pA = mean(cat_mc(:,i1:i2)==2,2);
    pB = mean(cat_mc(:,j1:j2)==2,2);

    rho_g1(k) = corr(pA,pB,'Type','Spearman');

end

figure( ...
    'Color','w', ...
    'Name','Rolling_Stability_Key_G1', ...
    'Position',[100 100 1000 600]);

plot(x_roll,rho_key,...
    '-o',...
    'LineWidth',2);

hold on;

plot(x_roll,rho_g1,...
    '-s',...
    'LineWidth',2);

yline(0.99,'--k');

xlabel('Número de simulações');
ylabel('Correlação de Spearman');

title('Rolling Stability das probabilidades');

legend({'Key','Grupo 1'},...
       'Location','southeast');

ylim([0.8 1.01]);

grid on;
box on;
%% =========================================================
% GRÁFICO EXTRA – DISTRIBUIÇÃO DOS PESOS POR ITERAÇÃO
%% =========================================================
figure('Color','w');
boxplot(W_samples, 'Labels', {'Impacto','Custo','CAPACIDADE NACIONAL DE IMPLEMENTAÇÃO','Prazo','Risco Verif'});
title('Dispersão dos Pesos Gerados pelo FAHP (Buckley) no Monte Carlo');
ylabel('Peso Relativo');
grid on;
box on;

%% =========================================================
% TABELA DE PROBABILIDADE DE CATEGORIZAÇÃO (% MONTE CARLO)
%% =========================================================
% Calcula as frequências absolutas (contagem de vezes em cada grupo)
freq_key = sum(cat_mc == 1, 2);
freq_g1  = sum(cat_mc == 2, 2);
freq_g2  = sum(cat_mc == 3, 2);
freq_g3  = sum(cat_mc == 4, 2);

% Transforma em porcentagem (%) com base no total de iterações (N_mc)
pct_key = (freq_key / N_mc) * 100;
pct_g1  = (freq_g1  / N_mc) * 100;
pct_g2  = (freq_g2  / N_mc) * 100;
pct_g3  = (freq_g3  / N_mc) * 100;

% Monta a tabela estruturada
T_categorias = table(req_labels(:), IDs, pct_key, pct_g1, pct_g2, pct_g3, ...
    'VariableNames', {'Req', 'ID', 'Pct_Key', 'Pct_Grupo1', 'Pct_Grupo2', 'Pct_Grupo3'});

% ORDENAÇÃO EM CASCATA: Primeiro por Key, depois por Grupo 1, depois por Grupo 2 (todos descrescentes)
T_categorias = sortrows(T_categorias, {'Pct_Key', 'Pct_Grupo1', 'Pct_Grupo2'}, {'descend', 'descend', 'descend'});

% Exibe no Command Window
disp('--- PORCENTAGEM DE CLASSIFICAÇÃO POR GRUPO (MONTE CARLO) ---');
disp(T_categorias);

% Exporta para uma nova aba ou novo arquivo Excel
writetable(T_categorias, 'MonteCarlo_Estabilidade_Categorias.xlsx');

%% =========================================================
% VIOLIN PLOT DO PHI_NET – TOP 10 REQUISITOS
% ==========================================================

n_top_violin = min(10,nReq);

% Seleciona os melhores pela posição média
[~, ordem_violin] = sort(mean_rank,'ascend');
idx_violin = ordem_violin(1:n_top_violin);

figure( ...
    'Color','w', ...
    'Name','Violin_PhiNet_Top10', ...
    'Position',[100 100 1200 700]);

hold on;

cores_violin = lines(n_top_violin);

for k = 1:n_top_violin

    idx_req = idx_violin(k);
    dados_phi = phi_mc(idx_req,:);

    % Remove valores inválidos
    dados_phi = dados_phi(isfinite(dados_phi));

    if numel(unique(dados_phi)) > 1
        [densidade,valores_phi] = ksdensity(dados_phi);
    else
        valores_phi = linspace( ...
            dados_phi(1)-0.001, ...
            dados_phi(1)+0.001, ...
            100);

        densidade = ones(size(valores_phi));
    end

    % Normaliza a largura do violino
    densidade = 0.35 * densidade / max(densidade);

    % Metade esquerda e direita
    x_esquerda = k - densidade;
    x_direita  = k + densidade;

    fill( ...
        [x_esquerda, fliplr(x_direita)], ...
        [valores_phi, fliplr(valores_phi)], ...
        cores_violin(k,:), ...
        'FaceAlpha',0.55, ...
        'EdgeColor',cores_violin(k,:), ...
        'LineWidth',1);

    % Mediana
    mediana_phi = median(dados_phi);

    plot( ...
        [k-0.22 k+0.22], ...
        [mediana_phi mediana_phi], ...
        'k-', ...
        'LineWidth',2);

    % Média
    media_phi_req = mean(dados_phi);

    plot( ...
        k,media_phi_req, ...
        'ko', ...
        'MarkerFaceColor','w', ...
        'MarkerSize',5);
end

xticks(1:n_top_violin);
xticklabels(req_labels(idx_violin));
xtickangle(30);

xlabel('Requisito');
ylabel('\phi_{net}');
title({ ...
    'Distribuição do \phi_{net} no Monte Carlo', ...
    sprintf('Top %d requisitos pela posição média',n_top_violin)});

grid on;
box on;
hold off;

%%
%% =========================================================
% HISTOGRAMA DA POSIÇÃO DE UM REQUISITO
% ==========================================================

% Requisito com melhor posição média
[~,req_hist] = min(mean_rank);

dados_rank = rank_mc(req_hist,:);

figure( ...
    'Color','w', ...
    'Name',['Histograma_Rank_' req_labels{req_hist}], ...
    'Position',[100 100 950 600]);

histogram( ...
    dados_rank, ...
    'BinEdges',0.5:1:(nReq+0.5), ...
    'Normalization','probability', ...
    'FaceColor',[0.85 0.33 0.10], ...
    'EdgeColor','white', ...
    'LineWidth',0.8);

hold on;

% Posição média
xline( ...
    mean(dados_rank), ...
    '--k', ...
    sprintf('Média = %.2f',mean(dados_rank)), ...
    'LineWidth',1.8, ...
    'LabelVerticalAlignment','middle');

% Posição determinística
xline( ...
    rank_base(req_hist), ...
    '-r', ...
    sprintf('S2 = %.0f',rank_base(req_hist)), ...
    'LineWidth',1.8, ...
    'LabelVerticalAlignment','bottom');

xlabel('Posição no ranking');
ylabel('Probabilidade');

title({ ...
    ['Distribuição da posição de ' req_labels{req_hist}], ...
    sprintf('Monte Carlo – %d iterações',N_mc)});

xticks(1:nReq);
xlim([0.5 nReq+0.5]);
ylim([0 max(histcounts( ...
    dados_rank, ...
    0.5:1:(nReq+0.5), ...
    'Normalization','probability')) * 1.20]);

grid on;
box on;
hold off;

%% =========================================================
% RANK ACCEPTABILITY MATRIX
% Labels shown only for probabilities >= 1%
%% =========================================================

acceptability = zeros(nReq, nReq);

for i = 1:nReq
    for r = 1:nReq
        rank_acceptability(i,r) = ...
            100 * sum(rank_mc(i,:) == r) / N_mc;
    end
end

[~, order_rank] = sort(mean_rank, 'ascend');

M = rank_acceptability(order_rank,:);
labels_rank = req_labels(order_rank);

figure('Color','w', ...
       'Position',[100 100 1200 750]);


imagesc(M);

colormap(turbo);      % <<< PALETA DE CORES

colorbar;             % <<< Barra de cores

clim([0 prctile(M(:),99)]);

xlabel('Rank Position');
ylabel('Requirement');
title('Rank Acceptability Matrix – Gaussian Monte Carlo');

xticks(1:nReq);
xticklabels(1:nReq);

yticks(1:nReq);
yticklabels(labels_rank);

set(gca, ...
    'FontSize',10, ...
    'TickLength',[0 0], ...
    'YDir','normal');

% Add numerical probabilities
for i = 1:nReq
    for r = 1:nReq

        value = M(i,r);

        % Show only values equal to or greater than 1%
        if value >= 1

            % Text contrast according to cell intensity
            if value >= 50
                text_color = 'white';
            else
                text_color = 'black';
            end

            text(r, i, sprintf('%.1f', value), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','middle', ...
                'FontSize',8, ...
                'FontWeight','bold', ...
                'Color',text_color);
        end
    end
end

box on;

save('Resultados_MC_Empirico.mat', ...
    'phi_mc','rank_mc','cat_mc','W_samples', ...
    'rank_base','phi_net_base_s2','req_labels','IDs','N_mc');

%% =========================================================
% SALVAMENTO AUTOMÁTICO DE TODAS AS FIGURAS EM PDF
% ==========================================================

% Localiza todas as figuras abertas
figuras_abertas = findall(groot, 'Type', 'figure');

% Organiza pela numeração da figura
[~, ordem_figuras] = sort([figuras_abertas.Number]);
figuras_abertas = figuras_abertas(ordem_figuras);

fprintf('\nSalvando figuras em PDF...\n');

for i = 1:numel(figuras_abertas)

    fig = figuras_abertas(i);

    % Usa o nome da figura, quando estiver definido
    nome_figura = string(fig.Name);

    % Se a figura não possui nome, usa a numeração
    if strlength(strtrim(nome_figura)) == 0
        nome_figura = sprintf('Figura_%02d', fig.Number);
    end

    % Remove caracteres incompatíveis com nomes de arquivos
    nome_figura = regexprep(nome_figura, ...
        '[^\w\-]', '_');

    % Evita sequências excessivas de "_"
    nome_figura = regexprep(nome_figura, ...
        '_+', '_');

    % Caminho final
    arquivo_pdf = fullfile( ...
        pasta_figuras, ...
        char(nome_figura + ".pdf"));

    % Salva como PDF vetorial
    exportgraphics( ...
        fig, ...
        arquivo_pdf, ...
        'ContentType','vector', ...
        'BackgroundColor','white');

    fprintf('Salva: %s\n', arquivo_pdf);

end

fprintf('\nTodas as figuras foram salvas em:\n%s\n', ...
    pasta_figuras);
tempo_total = toc;

fprintf('\n=====================================\n');
fprintf('Tempo total: %.2f segundos\n',tempo_total);
fprintf('Tempo total: %.2f minutos\n',tempo_total/60);
fprintf('Tempo total: %.2f horas\n',tempo_total/3600);
fprintf('=====================================\n');
%% =========================================================
%% FUNÇÕES AUXILIARES INCORPORADAS DO SEU PIPREM
%% =========================================================
function [w_s1_fuzzy,w_s1_crisp,info] = get_ws1_fuzzy_from_fahp_express(filename)
    [~, sheets] = xlsfinfo(filename); abas_interesse = sheets(1:end-1); num_especialistas = length(abas_interesse); n = 5;
    w_fuzzy_individual = zeros(n,4,num_especialistas); w_crisp_individual = zeros(n,num_especialistas);
    for s = 1:num_especialistas
        linha_txt = readcell(filename,'Sheet',abas_interesse{s},'Range','B4:F4');
        linha_ref = zeros(1,n); for k = 1:n, linha_ref(k) = saaty_linguistic2num(linha_txt{k}); end
        A = zeros(n,n); for i = 1:n, for j = 1:n, A(i,j) = linha_ref(j) / linha_ref(i); end; end
        m_fuzzy = zeros(n,n,4);
        for i = 1:n
            for j = 1:n
                m_fuzzy(i,j,:) = crisp_to_fuzzy_trap_interp(A(i,j));
            end
        end

        % Auditoria automática da reciprocidade fuzzy
        tol_rec = 1e-10;
        for i = 1:n
            for j = i+1:n
                tij = squeeze(m_fuzzy(i,j,:))';
                tji = squeeze(m_fuzzy(j,i,:))';

                esperado = [ ...
                    1/tij(4), ...
                    1/tij(3), ...
                    1/tij(2), ...
                    1/tij(1)];

                if max(abs(tji - esperado)) > tol_rec
                    error('Falha de reciprocidade fuzzy em (%d,%d).', i, j);
                end
            end
        end
        [w_crisp,w_fuzzy] = calc_fahp_buckley(m_fuzzy); w_fuzzy_individual(:,:,s) = w_fuzzy; w_crisp_individual(:,s) = w_crisp;
    end
    w_s1_fuzzy = mean(w_fuzzy_individual,3); w_s1_crisp = mean(w_s1_fuzzy,2); w_s1_crisp = w_s1_crisp ./ sum(w_s1_crisp);
    info.abas_interesse = abas_interesse; info.num_especialistas = num_especialistas; info.w_fuzzy_individual = w_fuzzy_individual; info.w_crisp_individual = w_crisp_individual;
end

function trap = crisp_to_fuzzy_trap_interp(x)

    % Escala trapezoidal adotada no FAHP-Express
    scale = [ ...
        1 1.0 1.0 1.0 1.0;
        2 1.0 1.5 2.5 3.0;
        3 2.0 2.5 3.5 4.0;
        4 3.0 3.5 4.5 5.0;
        5 4.0 4.5 5.5 6.0;
        6 5.0 5.5 6.5 7.0;
        7 6.0 6.5 7.5 8.0;
        8 7.0 7.5 8.5 9.0;
        9 8.0 8.5 9.0 9.0];

    % Validação
    if ~isscalar(x) || ~isfinite(x) || x <= 0
        error('O valor de comparação deve ser positivo e finito.');
    end

    % Os quocientes reconstruídos devem permanecer no domínio Saaty
    if x < 1/9 - 1e-12 || x > 9 + 1e-12
        error('Valor reconstruído fora da escala Saaty: %.6f', x);
    end

    % Igualdade
    if abs(x - 1) < 1e-12
        trap = [1 1 1 1];
        return;
    end

    % =====================================================
    % RECÍPROCOS: x < 1
    %
    % Não interpolar diretamente no domínio recíproco.
    % Primeiro fuzzifica 1/x e depois aplica o inverso fuzzy exato:
    % (l,m,n,u)^(-1) = (1/u,1/n,1/m,1/l)
    % =====================================================
    if x < 1

        directTrap = crisp_to_fuzzy_trap_interp(1/x);

        trap = [ ...
            1/directTrap(4), ...
            1/directTrap(3), ...
            1/directTrap(2), ...
            1/directTrap(1)];

        return;
    end

    % Valor exatamente presente na escala
    if abs(x - round(x)) < 1e-12
        k = round(x);
        trap = scale(k,2:5);
        return;
    end

    % =====================================================
    % INTERPOLAÇÃO LINEAR SOMENTE PARA x > 1
    % =====================================================
    lower = floor(x);
    upper = ceil(x);

    alpha = (x - lower) / (upper - lower);

    trap = ...
        (1-alpha)*scale(lower,2:5) + ...
        alpha*scale(upper,2:5);

end

%% =====================================================================
function [w_crisp,w_fuzzy] = calc_fahp_buckley(m_fuzzy)
    n = size(m_fuzzy,1); r = zeros(n,4);
    for i = 1:n, prod_row = [1 1 1 1]; for j = 1:n, prod_row = prod_row .* squeeze(m_fuzzy(i,j,:))'; end; r(i,:) = prod_row.^(1/n); end
    sum_r = sum(r,1); inv_sum = [1/sum_r(4), 1/sum_r(3), 1/sum_r(2), 1/sum_r(1)]; w_fuzzy = zeros(n,4);
    for i = 1:n, w_fuzzy(i,:) = r(i,:) .* inv_sum; end; w_crisp = mean(w_fuzzy,2); w_crisp = w_crisp ./ sum(w_crisp);
end

function [Phi_plus, Phi_minus, phi_net, Phi_plus_fuzzy, Phi_minus_fuzzy, Phi_net_fuzzy] = runFuzzyPrometheeTrap(F, w_fuzzy, critDir, pref_types, q_vals, p_vals)
    nReq = size(F, 1); nCrit = size(F, 2); PI = zeros(nReq, nReq, 4);
    for i = 1:nReq, for j = 1:nReq, if i == j, continue; end; pi_ij = [0, 0, 0, 0];
               for k = 1:nCrit, Ai = squeeze(F(i,k,:))'; Bj = squeeze(F(j,k,:))';
                if critDir(k) == 1, D = trap_sub(Ai, Bj); else, D = trap_sub(Bj, Ai); end
                Pk = pref_trap(D, pref_types(k), q_vals(k), p_vals(k)); Wk = squeeze(w_fuzzy(k,:))';
                pi_ij = trap_add(pi_ij, trap_mul_geldermann(Wk, Pk)); end; PI(i,j,:) = pi_ij; end; end
    Phi_plus_fuzzy = zeros(nReq,4); Phi_minus_fuzzy = zeros(nReq,4); Phi_net_fuzzy = zeros(nReq,4);
    Phi_plus = zeros(nReq,1); Phi_minus = zeros(nReq,1); phi_net = zeros(nReq,1);
    for i = 1:nReq, sumP = [0 0 0 0]; sumM = [0 0 0 0]; for j = 1:nReq, if i == j, continue; end
        sumP = trap_add(sumP, squeeze(PI(i,j,:))'); sumM = trap_add(sumM, squeeze(PI(j,i,:))'); end
        avgP = trap_scalar_div(sumP, (nReq - 1)); avgM = trap_scalar_div(sumM, (nReq - 1)); netF = trap_sub(avgP, avgM);
        Phi_plus_fuzzy(i,:) = avgP; Phi_minus_fuzzy(i,:) = avgM; Phi_net_fuzzy(i,:) = netF;
        Phi_plus(i) = defuzz_coa(avgP); Phi_minus(i) = defuzz_coa(avgM); phi_net(i) = defuzz_coa(netF); end
end

function trap = fuzzifyByScale(val, scale_max, TFN_eval_5, TFN_eval_7, TFN_eval_9)
    v = max(1, min(scale_max, round(val)));
    if scale_max == 5, trap = TFN_eval_5(v,:); elseif scale_max == 7, trap = TFN_eval_7(v,:); else, trap = TFN_eval_9(v,:); end
end

function C = trap_add(A, B), C = [A(1)+B(1), A(2)+B(2), A(3)+B(3), A(4)+B(4)]; end
function C = trap_sub(A, B), C = [A(1)-B(4), A(2)-B(3), A(3)-B(2), A(4)-B(1)]; end
function C = trap_scalar_div(A, s), C = A / s; end
function out = pref_trap(D, type, q, p), out = [pref_scalar(D(1), type, q, p), pref_scalar(D(2), type, q, p), pref_scalar(D(3), type, q, p), pref_scalar(D(4), type, q, p)]; out = sort(out); end

function p_res = pref_scalar(d, type, q, p)
    d = max(0, d);
    if type == 1, p_res = double(d > 0);
    elseif type == 4, if d <= q, p_res = 0; elseif d <= p, p_res = 0.5; else, p_res = 1; end
    else, p_res = 0; end
end

function C = trap_mul_geldermann(A, B)
    ml1 = A(2); mu1 = A(3); alpha1 = A(2)-A(1); beta1 = A(4)-A(3);
    ml2 = B(2); mu2 = B(3); alpha2 = B(2)-B(1); beta2 = B(4)-B(3);
    ml = ml1 * ml2; mu = mu1 * mu2; alpha = max(0, ml1 * alpha2 + ml2 * alpha1 - alpha1 * alpha2); beta = max(0, mu1 * beta2 + mu2 * beta1 + beta1 * beta2);
    C = sort([ml - alpha, ml, mu, mu + beta]); C(C < 0) = 0;
end

function x = defuzz_coa(T)
    a = T(1); b = T(2); c = T(3); d = T(4); if abs(d - a) < 1e-12, x = b; return; end
    den = 3 * (c + d - a - b); if abs(den) < 1e-12, x = mean(T); return; end
    x = ((c+d)^2 - c*d - (a+b)^2 + a*b) / den;
end

function val = saaty_linguistic2num(x)
    if ismissing(x), val = NaN; return; end; x = lower(strtrim(string(x)));
    switch x
        case "igual importância", val = 1; case "fracamente mais importante", val = 2; case "moderadamente mais importante", val = 3;
        case "moderadamente a fortemente mais importante", val = 4; case "fortemente mais importante", val = 5;
        case "fortemente a muito fortemente mais importante", val = 6; case "muito fortemente mais importante", val = 7;
        case "muito fortemente a extremamente mais importante", val = 8; case "extremamente mais importante", val = 9;
        otherwise, error('Escala Saaty não reconhecida: %s', x);
    end
end

function code = classToCode(cat_vec)
    code = zeros(numel(cat_vec),1);
    for i = 1:numel(cat_vec)
        switch string(cat_vec(i)), case "Key", code(i) = 1; case "Grupo 1", code(i) = 2; case "Grupo 2", code(i) = 3; case "Grupo 3", code(i) = 4; otherwise, code(i) = NaN; end
    end
end

function cat = classify_requirements_kmeans(phi_vec, key_idx)
    nReq = numel(phi_vec); cat = strings(nReq,1); key_idx = unique(key_idx(:)); cat(key_idx) = "Key";
    idx_rest = setdiff((1:nReq)', key_idx); n_rest = numel(idx_rest); if isempty(idx_rest), return; end
    if n_rest == 1, cat(idx_rest) = "Grupo 1"; return; end
    if n_rest == 2, [~, ord2] = sort(phi_vec(idx_rest), 'descend'); cat(idx_rest(ord2(1))) = "Grupo 1"; cat(idx_rest(ord2(2))) = "Grupo 2"; return; end
    phi_rest = phi_vec(idx_rest); [idx_km, C] = kmeans(phi_rest, min(3, n_rest), 'Replicates', 20, 'Start', 'plus', 'Distance', 'sqeuclidean');
    [~, ordC] = sort(C, 'descend'); cluster_to_group = strings(min(3, n_rest),1);
    if length(ordC) >= 1, cluster_to_group(ordC(1)) = "Grupo 1"; end; if length(ordC) >= 2, cluster_to_group(ordC(2)) = "Grupo 2"; end; if length(ordC) >= 3, cluster_to_group(ordC(3)) = "Grupo 3"; end
    for i = 1:n_rest, cat(idx_rest(i)) = cluster_to_group(idx_km(i)); end
end

function val = linguistic2num(x)
    if isempty(x) || (isstring(x) && ismissing(x)), error('Valor vazio ou missing encontrado na planilha'); end
    if isnumeric(x), if isnan(x), error('Valor NaN encontrado na planilha'); end; val = x; return; end
    str = char(lower(strtrim(string(x))));
    if strcmp(str, 'muito alto'), val = 7; elseif strcmp(str, 'alto'), val = 6; elseif strcmp(str, 'moderadamente alto'), val = 5;
    elseif strcmp(str, 'médio') || strcmp(str, 'medio'), val = 4; elseif strcmp(str, 'moderadamente baixo'), val = 3;
    elseif strcmp(str, 'baixo'), val = 2; elseif strcmp(str, 'muito baixo'), val = 1; else, error('Valor linguístico desconhecido: %s', str); end
end
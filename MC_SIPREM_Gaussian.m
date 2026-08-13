clc; clear all; close all;

%% CONFIGURAÇÕES
N_mc = 100; % Number of Monte Carlo iterations
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

crit_names = {'Impact', 'Cost', 'National Industrial Capability', 'Lead Time', 'Verification Risk'};
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

%% GAUSSIAN PARAMETERS ESTIMATED FROM EXPERT RESPONSES
% Weight judgments: one normal distribution per criterion, estimated across
% the experts in the FAHP spreadsheet.
weight_mu = mean(linhas_ref_all, 1, 'omitnan');
weight_sigma = std(linhas_ref_all, 0, 1, 'omitnan');
weight_sigma(~isfinite(weight_sigma)) = 0;

% Requirement attributes: one normal distribution per requirement-criterion
% cell, estimated across the experts in the attributes spreadsheet.
attribute_mu = mean(data_all, 3, 'omitnan');
attribute_sigma = std(data_all, 0, 3, 'omitnan');
attribute_sigma(~isfinite(attribute_sigma)) = 0;

%% DETERMINISTIC S2 BASE SCENARIO
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
top1_count = zeros(nReq,1);
cat_mc = zeros(nReq, N_mc);   
W_samples = zeros(N_mc, nCrit);

%% GAUSSIAN MONTE CARLO LOOP ALIGNED WITH S2
for mc = 1:N_mc
    %% 1. GAUSSIAN SAMPLING OF FAHP WEIGHT JUDGMENTS
    % Each criterion judgment is sampled from N(mean, standard deviation)
    % estimated from all experts. Values are truncated to the Saaty range.
    linha_ref_mc = zeros(1, nCrit);
    for k = 1:nCrit
        linha_ref_mc(k) = truncated_normal_sample( ...
            weight_mu(k), weight_sigma(k), 1, 9);
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
    [w_crisp_mc_iter, w_fuzzy_mc_iter] = calc_fahp_buckley(m_fuzzy_mc);
    W_samples(mc, :) = w_crisp_mc_iter(:)';

    %% 2. GAUSSIAN SAMPLING OF REQUIREMENT ATTRIBUTES
    % For every requirement-criterion response, a normal distribution is
    % estimated across experts. Each S2 expert realization receives an
    % independent draw from the same cell-specific distribution.
    phi_net_experts_mc = zeros(nReq, nExperts);
    for e = 1:nExperts
        F_e_mc = zeros(nReq, nCrit, 4);
        for r = 1:nReq
            for c = 1:nCrit
                sampled_value = truncated_normal_sample( ...
                    attribute_mu(r,c), attribute_sigma(r,c), ...
                    scale_min(c), scale_max(c));

                % Continuous interpolation between adjacent fuzzy scales.
                F_e_mc(r,c,:) = fuzzifyByScaleContinuous( ...
                    sampled_value, scale_max(c), ...
                    TFN_eval_5, TFN_eval_7, TFN_eval_9);
            end
        end

        [~, ~, phi_net_e_mc, ~, ~, ~] = runFuzzyPrometheeTrap( ...
            F_e_mc, w_fuzzy_mc_iter, critDir, pref_types, q_base, p_base);
        phi_net_experts_mc(:,e) = phi_net_e_mc;
    end

    %% 3. POSTERIOR S2 AGGREGATION
    phi_now = mean(phi_net_experts_mc, 2);
    rank_now = nReq + 1 - tiedrank(phi_now);

    phi_mc(:,mc) = phi_now;
    rank_mc(:,mc) = rank_now;

    % Category assignment and Top-1 count.
    is_key_mc = rand(nReq,1) < prob_key_req;
    key_idx_mc = find(is_key_mc);
    cat_now = classify_requirements_kmeans(phi_now, key_idx_mc);
    cat_mc(:,mc) = classToCode(cat_now);

    idx_top = find(rank_now == 1);
    top1_count(idx_top) = top1_count(idx_top) + 1;
end

%% RESULTADOS E EXPORTAÇÃO
mean_rank = mean(rank_mc, 2);
std_rank  = std(rank_mc, 0, 2);
freq_top1 = top1_count / N_mc;
mean_phi  = mean(phi_mc, 2);
std_phi   = std(phi_mc, 0, 2);
T_mc = table(req_labels(:), IDs, rank_base(:), mean_rank, std_rank, freq_top1, mean_phi, std_phi, ...
    'VariableNames', {'Req','ID','Rank_Base_S2','MeanRank_MC','StdRank_MC','FreqTop1_MC','MeanPhi_MC','StdPhi_MC'});
T_mc = sortrows(T_mc, 'MeanRank_MC', 'ascend');
disp('--- GAUSSIAN MONTE CARLO RESULTS (S2) ---');
disp(T_mc);
writetable(T_mc, 'MonteCarlo_Gaussian_S2_Summary.xlsx');

%% =========================================================
% TABELA DE PROBABILIDADE DE CATEGORIZAÇÃO EM CASCATA
%% =========================================================
freq_key = sum(cat_mc == 1, 2); freq_g1 = sum(cat_mc == 2, 2); freq_g2 = sum(cat_mc == 3, 2); freq_g3 = sum(cat_mc == 4, 2);
pct_key = (freq_key / N_mc) * 100; pct_g1 = (freq_g1 / N_mc) * 100; pct_g2 = (freq_g2 / N_mc) * 100; pct_g3 = (freq_g3 / N_mc) * 100;

T_categorias = table(req_labels(:), IDs, pct_key, pct_g1, pct_g2, pct_g3, ...
    'VariableNames', {'Requirement', 'ID', 'Pct_Key', 'Pct_Group1', 'Pct_Group2', 'Pct_Group3'});
T_categorias = sortrows(T_categorias, {'Pct_Key', 'Pct_Group1', 'Pct_Group2'}, {'descend', 'descend', 'descend'});
writetable(T_categorias, 'MonteCarlo_Gaussian_Category_Stability.xlsx');

%% =========================================================
% PLOTAGEM DOS GRÁFICOS ATUALIZADOS
%% =========================================================
labels = req_labels; phi_all = phi_mc; phi_std = std(phi_all, 0, 2); rank_det = rank_base(:); rank_mc_plot = mean(rank_mc, 2);
rho = corr(rank_det, rank_mc_plot, 'Type', 'Spearman');
prob_key = freq_key / N_mc; phi_mean_iter = mean(phi_all, 1);

sens = zeros(1, nCrit);
for j = 1:nCrit
    sens(j) = corr(W_samples(:,j), phi_mean_iter', 'Type', 'Pearson');
end

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
set(gca, 'YDir', 'reverse', 'XLim', [0.1, 2.9], 'YLim', [0.5, max([rank_det_ajustado; rank_mc_ajustado]) + 0.5], 'XTick', [1 2], 'XTickLabel', {'Deterministic (S2)', 'Gaussian MC S2 (mean)'}, 'FontSize', 11, 'FontName', 'Helvetica');
title(['Global S2 Ranking Sensitivity (Spearman \rho = ' num2str(rho,3) ')'], 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Rank Position', 'FontSize', 12); grid on; box on; hold off;

% GRÁFICO 7 – SENSIBILIDADE GLOBAL
figure('Color','w'); bar(sens); title('Global S2 Sensitivity: Weight vs. Mean Net Flow Correlation');
xticks(1:nCrit); xticklabels(crit_names); ylabel('Pearson Correlation'); grid on; box on;

% GRÁFICO 8 – CONVERGÊNCIA MONTE CARLO
nPts = 20; step = max(1, floor(N_mc / nPts)); x_conv = zeros(nPts,1); conv_vals = zeros(nPts,1);
for k = 1:nPts
    idx_end = min(k*step, N_mc); phi_temp = mean(phi_all(:,1:idx_end), 2);
    [~, ord_temp] = sort(phi_temp, 'descend'); rank_temp = zeros(nReq,1); rank_temp(ord_temp) = 1:nReq;
    conv_vals(k) = corr(rank_det, rank_temp, 'Type', 'Spearman'); x_conv(k) = idx_end;
end
figure('Color','w'); plot(x_conv, conv_vals, '-o', 'LineWidth', 2); title('Gaussian Monte Carlo Ranking Convergence (Spearman \rho)'); xlabel('Number of Simulations'); ylabel('\rho with Deterministic Ranking'); grid on; box on;

%% =========================================================
% GRÁFICO EXTRA – DISTRIBUIÇÃO DOS PESOS POR ITERAÇÃO
%% =========================================================
figure('Color','w');
boxplot(W_samples, 'Labels', crit_names);
title('Distribution of FAHP (Buckley) Weights in Gaussian Monte Carlo');
ylabel('Relative Weight');
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
    'VariableNames', {'Requirement', 'ID', 'Pct_Key', 'Pct_Group1', 'Pct_Group2', 'Pct_Group3'});

% ORDENAÇÃO EM CASCATA: Primeiro por Key, depois por Grupo 1, depois por Grupo 2 (todos descrescentes)
T_categorias = sortrows(T_categorias, {'Pct_Key', 'Pct_Group1', 'Pct_Group2'}, {'descend', 'descend', 'descend'});

% Exibe no Command Window
disp('--- CATEGORY CLASSIFICATION PERCENTAGES (GAUSSIAN MONTE CARLO) ---');
disp(T_categorias);

% Exporta para uma nova aba ou novo arquivo Excel
writetable(T_categorias, 'MonteCarlo_Gaussian_Category_Stability.xlsx');

save('Resultados_MC_Gaussiano.mat', ...
    'phi_mc','rank_mc','cat_mc','W_samples', ...
    'rank_base','phi_net_base_s2','req_labels','IDs','N_mc');

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
        m_fuzzy = zeros(n,n,4); for i = 1:n, for j = 1:n, m_fuzzy(i,j,:) = crisp_to_fuzzy_trap_interp(A(i,j)); end; end
        [w_crisp,w_fuzzy] = calc_fahp_buckley(m_fuzzy); w_fuzzy_individual(:,:,s) = w_fuzzy; w_crisp_individual(:,s) = w_crisp;
    end
    w_s1_fuzzy = mean(w_fuzzy_individual,3); w_s1_crisp = mean(w_s1_fuzzy,2); w_s1_crisp = w_s1_crisp ./ sum(w_s1_crisp);
    info.abas_interesse = abas_interesse; info.num_especialistas = num_especialistas; info.w_fuzzy_individual = w_fuzzy_individual; info.w_crisp_individual = w_crisp_individual;
end

function trap = crisp_to_fuzzy_trap_interp(x)

    % =========================================================
    % ESCALA TRAPEZOIDAL ADOTADA
    % =========================================================

    scale = [
        1 1.0 1.0 1.0 1.0;
        2 1.0 1.5 2.5 3.0;
        3 2.0 2.5 3.5 4.0;
        4 3.0 3.5 4.5 5.0;
        5 4.0 4.5 5.5 6.0;
        6 5.0 5.5 6.5 7.0;
        7 6.0 6.5 7.5 8.0;
        8 7.0 7.5 8.5 9.0;
        9 8.0 8.5 9.0 9.0
    ];

    % =========================================================
    % VALIDAÇÃO
    % =========================================================

    if ~isscalar(x) || ~isfinite(x) || x <= 0
        error('Comparison value must be positive and finite.');
    end

    if x < 1/9 - 1e-12 || x > 9 + 1e-12
        error('Reconstructed value outside Saaty scale: %.6f', x);
    end

    % =========================================================
    % IDENTIDADE
    % =========================================================

    if abs(x - 1) < 1e-12
        trap = [1 1 1 1];
        return;
    end

    % =========================================================
    % RECÍPROCOS: x < 1
    %
    % NÃO interpolar diretamente.
    % Fuzzifica 1/x e toma o inverso fuzzy exato.
    %
    % (l,m,n,u)^(-1) = (1/u,1/n,1/m,1/l)
    % =========================================================

    if x < 1

        directTrap = crisp_to_fuzzy_trap_interp(1/x);

        trap = [
            1/directTrap(4), ...
            1/directTrap(3), ...
            1/directTrap(2), ...
            1/directTrap(1)
        ];

        return;
    end

    % =========================================================
    % VALOR EXATO DA ESCALA
    % =========================================================

    if abs(x - round(x)) < 1e-12

        k = round(x);

        trap = scale(k,2:5);

        return;
    end

    % =========================================================
    % INTERPOLAÇÃO SOMENTE PARA VALORES INTERMEDIÁRIOS > 1
    % =========================================================

    lower = floor(x);
    upper = ceil(x);

    alpha = ...
        (x - lower) / ...
        (upper - lower);

    trap = ...
        (1-alpha)*scale(lower,2:5) + ...
        alpha*scale(upper,2:5);

end

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
    % Deterministic wrapper retained for the original integer responses.
    trap = fuzzifyByScaleContinuous(val, scale_max, TFN_eval_5, TFN_eval_7, TFN_eval_9);
end

function trap = fuzzifyByScaleContinuous(val, scale_max, TFN_eval_5, TFN_eval_7, TFN_eval_9)
    % Linear interpolation between adjacent linguistic fuzzy numbers, so the
    % continuous Gaussian draw is not rounded back to an integer category.
    v = max(1, min(scale_max, val));
    if scale_max == 5
        scale = TFN_eval_5;
    elseif scale_max == 7
        scale = TFN_eval_7;
    else
        scale = TFN_eval_9;
    end

    lo = floor(v);
    hi = ceil(v);
    if lo == hi
        trap = scale(lo,:);
    else
        alpha = v - lo;
        trap = (1-alpha) * scale(lo,:) + alpha * scale(hi,:);
    end
end

function x = truncated_normal_sample(mu, sigma, lower_bound, upper_bound)
    % Draw from N(mu,sigma), truncated by rejection sampling. Degenerate or
    % invalid standard deviations collapse safely to the bounded mean.
    if ~isfinite(mu)
        error('Cannot sample from a Gaussian distribution with a non-finite mean.');
    end
    if ~isfinite(sigma) || sigma <= 1e-12
        x = min(upper_bound, max(lower_bound, mu));
        return;
    end

    max_attempts = 1000;
    for attempt = 1:max_attempts
        candidate = mu + sigma * randn;
        if candidate >= lower_bound && candidate <= upper_bound
            x = candidate;
            return;
        end
    end

    % Extremely unlikely fallback when the mean is far outside the bounds.
    x = min(upper_bound, max(lower_bound, mu));
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
        switch string(cat_vec(i)), case "Key", code(i) = 1; case "Group 1", code(i) = 2; case "Group 2", code(i) = 3; case "Group 3", code(i) = 4; otherwise, code(i) = NaN; end
    end
end

function cat = classify_requirements_kmeans(phi_vec, key_idx)
    nReq = numel(phi_vec); cat = strings(nReq,1); key_idx = unique(key_idx(:)); cat(key_idx) = "Key";
    idx_rest = setdiff((1:nReq)', key_idx); n_rest = numel(idx_rest); if isempty(idx_rest), return; end
    if n_rest == 1, cat(idx_rest) = "Group 1"; return; end
    if n_rest == 2, [~, ord2] = sort(phi_vec(idx_rest), 'descend'); cat(idx_rest(ord2(1))) = "Group 1"; cat(idx_rest(ord2(2))) = "Group 2"; return; end
    phi_rest = phi_vec(idx_rest); [idx_km, C] = kmeans(phi_rest, min(3, n_rest), 'Replicates', 20, 'Start', 'plus', 'Distance', 'sqeuclidean');
    [~, ordC] = sort(C, 'descend'); cluster_to_group = strings(min(3, n_rest),1);
    if length(ordC) >= 1, cluster_to_group(ordC(1)) = "Group 1"; end; if length(ordC) >= 2, cluster_to_group(ordC(2)) = "Group 2"; end; if length(ordC) >= 3, cluster_to_group(ordC(3)) = "Group 3"; end
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
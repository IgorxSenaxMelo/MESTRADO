clc; clear all; close all;
%% CONFIGURAÇÕES
N_mc = 100;
pct_var = 0.20;     % 20% parametrizado
rng(42);
%%
input_file = 'dados_requisitos_lista.xlsx';
all_sheets = sheetnames(input_file);
all_sheets = all_sheets(1:end-1); % IGNORA ÚLTIMA
nExperts = numel(all_sheets);

nCrit = 5;
crit_names = {'Impacto', 'Custo', 'RiscoTec', 'Prazo', 'RiscoVerif'};
critDir = [1, -1, 1, -1, -1];
pref_types = [1, 4, 4, 4, 4];

scale_max = [7, 7, 7, 7, 7];
scale_min = [1, 1, 1, 1, 1];
A_scale = scale_max - scale_min;

q_base = [0, 0.06*A_scale(2), 0.06*A_scale(3), 0.06*A_scale(4), 0.06*A_scale(5)];
p_base = [0, 0.21*A_scale(2), 0.21*A_scale(3), 0.21*A_scale(4), 0.21*A_scale(5)];

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

%% LEITURA DOS DADOS-BASE
T0 = readtable(input_file, 'Sheet', all_sheets{1}, 'VariableNamingRule', 'preserve');
IDs = T0{:,1};
data0 = T0{:,3:(2+nCrit)};
[nReq, ~] = size(data0);
req_labels = arrayfun(@(x) sprintf('R%d', x), 1:nReq, 'UniformOutput', false);

%N_mc = ceil((2.58^2 * nReq * 0.25) / (0.05^2)); % by performing 10.000 iterations which consists a typical number of acceptable computations (Lahdelma and Salminen 2010)

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




% pesos S2
[w_fuzzy_group, w_group_defuzz, ~] = get_ws1_fuzzy_from_fahp('F_AHP.xlsx');

%% S2
[phi_base, rank_base] = run_s2_fuzzy_promethee_once( ...
    data_group, w_fuzzy_group, critDir, pref_types, q_base, p_base, ...
    scale_max, TFN_eval_5, TFN_eval_7, TFN_eval_9);

%% PRÉ-ALOCAÇÃO
phi_mc = zeros(nReq, N_mc);
rank_mc = zeros(nReq, N_mc);
top1_count = zeros(nReq,1);

% categorias Monte Carlo
cat_mc = zeros(nReq, N_mc);   % 1=Key, 2=Grupo1, 3=Grupo2, 4=Grupo3

% pesos crisp amostrados (para sensibilidade)
W_samples = zeros(N_mc, nCrit);

% leitura base para definição dos candidatos Key por maioria
data_all = zeros(nReq, nCrit, nExperts);
impacto_ind = zeros(nReq, nExperts);

for e = 1:nExperts
    Te = readtable(input_file, 'Sheet', all_sheets{e}, 'VariableNamingRule', 'preserve');
    data_raw = table2cell(Te(:,3:(2+nCrit)));

data_e = zeros(size(data_raw));

for i = 1:size(data_raw,1)
    for k = 1:size(data_raw,2)
        data_e(i,k) = linguistic2num(data_raw{i,k});
    end
end
    data_all(:,:,e) = data_e;
    impacto_ind(:,e) = data_e(:,1);

    impacto_base = squeeze(data_all(:,1,:));

prob_key_req = sum(impacto_base == scale_max(1),2) / nExperts;
end


%% MONTE CARLO
% Fontes de incerteza modeladas:
%
% (1) Avaliações dos especialistas (EMPÍRICA)
% (2) Pesos FAHP (PARAMÉTRICA) do cenario S2
% (3) Limiares de preferência PROMETHEE (q e p)
% (4) Números fuzzy linguísticos (TFNs)

for mc = 1:N_mc

    % 1) pesos fuzzy perturbados e renormalizados por coluna
    w_mc = w_fuzzy_group .* (1 + pct_var*(2*rand(size(w_fuzzy_group))-1));
    w_mc = max(w_mc, 1e-6);
    % pesos crisp equivalentes desta simulação
w_crisp_now = mean(w_mc, 2);
w_crisp_now = w_crisp_now / sum(w_crisp_now);
W_samples(mc,:) = w_crisp_now';

    for c = 1:4
        w_mc(:,c) = w_mc(:,c) / sum(w_mc(:,c));
    end

    % garante ordenação trapezoidal
    for k = 1:nCrit
        w_mc(k,:) = sort(w_mc(k,:));
    end

% 2) amostragem empírica das avaliações dos especialistas

data_mc = zeros(nReq,nCrit);

for r = 1:nReq
    for c = 1:nCrit

        vals = squeeze(data_all(r,c,:));

        uvals = unique(vals);

        prob = zeros(size(uvals));

        for k = 1:length(uvals)
            prob(k) = sum(vals == uvals(k));
        end

        prob = prob / sum(prob);

        idx = randsample(length(uvals),1,true,prob);

        data_mc(r,c) = uvals(idx);

    end
end

    % 3) q e p perturbados em ±20%
    q_mc = q_base .* (1 + pct_var*(2*rand(size(q_base))-1));
    p_mc = p_base .* (1 + pct_var*(2*rand(size(p_base))-1));

    % garante q <= p
    for k = 1:nCrit
        if q_mc(k) > p_mc(k)
            aux = q_mc(k);
            q_mc(k) = p_mc(k);
            p_mc(k) = aux;
        end
    end

    % 2) perturbação dos números fuzzy (TFN)
TFN5_mc = perturb_TFN_monotonic(TFN_eval_5, pct_var, 1, 5);
TFN7_mc = perturb_TFN_monotonic(TFN_eval_7, pct_var, 1, 7);
TFN9_mc = perturb_TFN_monotonic(TFN_eval_9, pct_var, 1, 9);

    % 4) roda uma vez
    [phi_now, rank_now] = run_s2_fuzzy_promethee_once( ...
        data_mc, w_mc, critDir, pref_types, q_mc, p_mc, ...
        scale_max, TFN5_mc, TFN7_mc, TFN9_mc);

    phi_mc(:,mc) = phi_now;
    rank_mc(:,mc) = rank_now;

    % classificação da simulação

    % sorteia quais requisitos serão Key nesta iteração
is_key_mc = rand(nReq,1) < prob_key_req;

key_idx_mc = find(is_key_mc);

cat_now = classify_requirements_kmeans(phi_now, key_idx_mc);
cat_mc(:,mc) = classToCode(cat_now);

    idx_top = find(rank_now == 1);
    top1_count(idx_top) = top1_count(idx_top) + 1;
end

%% RESULTADOS
mean_rank = mean(rank_mc, 2);
std_rank  = std(rank_mc, 0, 2);
freq_top1 = top1_count / N_mc;
mean_phi  = mean(phi_mc, 2);
std_phi   = std(phi_mc, 0, 2);

T_mc = table(req_labels(:), IDs, rank_base(:), mean_rank, std_rank, freq_top1, mean_phi, std_phi, ...
    'VariableNames', {'Req','ID','Rank_Base','MeanRank_MC','StdRank_MC','FreqTop1_MC','MeanPhi_MC','StdPhi_MC'});

T_mc = sortrows(T_mc, 'MeanRank_MC', 'ascend');

disp('--- RESULTADOS MONTE CARLO ---');
disp(T_mc);

writetable(T_mc, 'MonteCarlo_S2_Resumo.xlsx');

%% =========================================================
% PREPARAÇÃO PARA OS GRÁFICOS
%% =========================================================
labels = req_labels;

phi_all = phi_mc;
phi_std = std(phi_all, 0, 2);

% ranking determinístico
rank_det = rank_base(:);

% ranking estocástico resumido
rank_mc_mean = mean(rank_mc, 2);
rank_mc_med  = median(rank_mc, 2);
rank_mc_p95  = prctile(rank_mc', 95)';   % "quase worst-case"

% escolha para gráficos comparativos
rank_mc_plot = rank_mc_mean;   % troque para rank_mc_p95 se quiser algo mais conservador

% Spearman entre ranking determinístico e ranking estocástico médio
rho = corr(rank_det, rank_mc_plot, 'Type', 'Spearman');

% probabilidade / frequência das categorias
freq_key = sum(cat_mc == 1, 2);
freq_g1  = sum(cat_mc == 2, 2);
freq_g2  = sum(cat_mc == 3, 2);
freq_g3  = sum(cat_mc == 4, 2);

prob_key = freq_key / N_mc;

% média do net flow por simulação
phi_mean_iter = mean(phi_all, 1);

% probabilidade Top-1 e Top-3
top1 = zeros(nReq,1);
top3 = zeros(nReq,1);

for s = 1:N_mc
    [~, idx] = sort(phi_all(:,s), 'descend');
    top1(idx(1)) = top1(idx(1)) + 1;
    top3(idx(1:min(3,nReq))) = top3(idx(1:min(3,nReq))) + 1;
end

top1 = top1 / N_mc;
top3 = top3 / N_mc;

% sensibilidade: correlação entre pesos e net flow médio da simulação
sens = zeros(1, nCrit);
for j = 1:nCrit
    sens(j) = corr(W_samples(:,j), phi_mean_iter', 'Type', 'Pearson');
end

%% GRÁFICOs
out.rank_mc = rank_mc;
out.phi_mc  = phi_mc;
out.rank_base = rank_base;

%% =========================================================
% GRÁFICO 1 – DESVIO PADRÃO DO NET FLOW
%% =========================================================
figure('Color','w');
bar(phi_std, 'FaceColor', [0.5 0.5 0.5]);
title('Desvio Padrão do Net Flow (Incerteza do Requisito)');
xticks(1:nReq);
xticklabels(labels);
xtickangle(45);
grid on;
ylabel('\sigma_{\Phi}');
box on;

%% =========================================================
% GRÁFICO 2 – PROBABILIDADE DE CLASSIFICAÇÃO COMO KEY
%% =========================================================
figure('Color', 'w');
b2 = bar(prob_key, 'FaceColor', [0.2 0.2 0.5]);
title('Probabilidade de Classificação como Key');
ylabel('Probabilidade');
xticks(1:nReq);
xticklabels(labels);
xtickangle(45);
grid on;
box on;

text(b2.XEndPoints, b2.YEndPoints, ...
    string(round(prob_key*100,1)) + "%", ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'bottom', ...
    'FontWeight', 'bold');

%% =========================================================
% GRÁFICO 3 – FREQUÊNCIA DAS CATEGORIAS
%% =========================================================
figure('Color','w');
bar([freq_key freq_g1 freq_g2 freq_g3] / N_mc, 'stacked');
title('Estabilidade de Categorização (Monte Carlo)');
legend('Key','Grupo 1','Grupo 2','Grupo 3', 'Location','northeastoutside');
xticks(1:nReq);
xticklabels(labels);
xtickangle(45);
grid on;
ylabel('Frequência Relativa');
box on;

%% =========================================================
% GRÁFICO 4 – BUMP CHART
%% =========================================================
figure('Color', 'w', 'Position', [100, 100, 750, 550]);
hold on;

mudou = abs(rank_det - rank_mc_plot) > 0.5;
cores_artigo = lines(nReq);

for i = 1:nReq
    line_w = 1.2;
    estilo = '--';
    cor_i = cores_artigo(i,:);

    if mudou(i)
        line_w = 2.5;
        estilo = '-';
    end

    plot([1, 2], [rank_det(i), rank_mc_plot(i)], estilo, ...
        'LineWidth', line_w, ...
        'Marker', 'o', ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', cor_i, ...
        'Color', cor_i);

    text(0.92, rank_det(i), labels{i}, ...
        'HorizontalAlignment', 'right', ...
        'FontWeight', 'bold');

    text(2.08, rank_mc_plot(i), labels{i}, ...
        'HorizontalAlignment', 'left', ...
        'FontWeight', 'bold');
end

set(gca, 'YDir', 'reverse', ...
         'XLim', [0.4, 2.6], ...
         'YLim', [0.5, nReq+0.5], ...
         'XTick', [1 2], ...
         'XTickLabel', {'Determinístico', 'Estocástico (médio)'});

title(['Sensibilidade de Ranking (Spearman \rho = ' num2str(rho,3) ')'], 'FontSize', 12);
ylabel('Posição');
grid on;
box on;
hold off;

%% =========================================================
% GRÁFICO 5 – BOXPLOT DO NET FLOW
%% =========================================================
figure('Color','w');
boxplot(phi_all', 'Labels', labels);
title('Distribuição do Net Flow por Requisito');
ylabel('\Phi');
grid on;
box on;

% %% =========================================================
% % GRÁFICO 6 – PROBABILIDADE TOP-1 E TOP-3
% %% =========================================================
% figure('Color','w');
% bar([top1 top3]);
% legend('Top 1','Top 3', 'Location','northoutside', 'Orientation','horizontal');
% title('Probabilidade de Posição de Destaque');
% xticks(1:nReq);
% xticklabels(labels);
% xtickangle(45);
% ylabel('Probabilidade');
% grid on;
% box on;

%% =========================================================
% GRÁFICO 7 – SENSIBILIDADE GLOBAL
%% =========================================================
figure('Color','w');
bar(sens);
title('Sensibilidade Global: Correlação Peso × Net Flow Médio');
xticks(1:nCrit);
xticklabels({'Impacto','Custo','Risco Tec','Prazo','Risco Verif'});
ylabel('Correlação de Pearson');
grid on;
box on;

%% =========================================================
% GRÁFICO 8 – CONVERGÊNCIA MONTE CARLO
%% =========================================================
nPts = 20;
step = max(1, floor(N_mc / nPts));
x_conv = zeros(nPts,1);
conv_vals = zeros(nPts,1);

for k = 1:nPts
    idx_end = min(k*step, N_mc);
    idx = 1:idx_end;

    phi_temp = mean(phi_all(:,idx), 2);
    [~, ord_temp] = sort(phi_temp, 'descend');

    rank_temp = zeros(nReq,1);
    rank_temp(ord_temp) = 1:nReq;

    conv_vals(k) = corr(rank_det, rank_temp, 'Type', 'Spearman');
    x_conv(k) = idx_end;
end

figure('Color','w');
plot(x_conv, conv_vals, '-o', 'LineWidth', 2);
title('Convergência do Ranking (Spearman \rho)');
xlabel('Número de Simulações');
ylabel('\rho com Ranking Determinístico');
grid on;
box on;

%% =========================================================
% GRÁFICO 9 – VARIAÇÃO ABSOLUTA DE RANKING
%% =========================================================
delta_rank = abs(rank_det - rank_mc_plot);

figure('Color','w');
bar(delta_rank);
title('Variação Absoluta de Ranking por Requisito');
xticks(1:nReq);
xticklabels(labels);
xtickangle(45);
ylabel('| \Delta Ranking |');
grid on;
box on;

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

    % Evita erro se houver poucos requisitos não-Key
    if n_rest == 1
        cat(idx_rest) = "Grupo 1";
        return;
    elseif n_rest == 2
        [~, ord2] = sort(phi_vec(idx_rest), 'descend');
        cat(idx_rest(ord2(1))) = "Grupo 1";
        cat(idx_rest(ord2(2))) = "Grupo 2";
        return;
    end

    k = min(3, n_rest);
    phi_rest = phi_vec(idx_rest);

    [idx_km, C] = kmeans(phi_rest, k, ...
        'Replicates', 20, ...
        'Start', 'plus', ...
        'Distance', 'sqeuclidean');

    [~, ordC] = sort(C, 'descend');

    cluster_to_group = strings(k,1);
    if k >= 1, cluster_to_group(ordC(1)) = "Grupo 1"; end
    if k >= 2, cluster_to_group(ordC(2)) = "Grupo 2"; end
    if k >= 3, cluster_to_group(ordC(3)) = "Grupo 3"; end

    for i = 1:n_rest
        cat(idx_rest(i)) = cluster_to_group(idx_km(i));
    end
end

function TFN_var = perturb_TFN_monotonic(TFN_base, pct_var, scale_min, scale_max)
% ---------------------------------------------------------
% Perturba uma tabela de TFNs/TrFNs preservando:
% 1) limites da escala [scale_min, scale_max]
% 2) ordem interna: a <= b <= c <= d
% 3) monotonicidade global aproximada entre níveis
%
% Entrada:
%   TFN_base  : matriz n x 4
%   pct_var   : ex. 0.20
%   scale_min : mínimo da escala (ex. 1)
%   scale_max : máximo da escala (ex. 9)
%
% Saída:
%   TFN_var   : matriz n x 4 perturbada e coerente
% ---------------------------------------------------------

    nLevels = size(TFN_base,1);
    TFN_var = zeros(size(TFN_base));

    % parâmetros de controle:
    % deslocamento pequeno do centro e variação das larguras
    center_var = 0.30 * pct_var;   % menor que pct_var para não deslocar demais
    width_var  = 1.00 * pct_var;   % variação principal fica na largura

    for i = 1:nLevels
        a0 = TFN_base(i,1);
        b0 = TFN_base(i,2);
        c0 = TFN_base(i,3);
        d0 = TFN_base(i,4);

        % centro do núcleo
        core_center0 = (b0 + c0) / 2;

        % semi-larguras
        left_support0  = core_center0 - a0;
        left_core0     = core_center0 - b0;
        right_core0    = c0 - core_center0;
        right_support0 = d0 - core_center0;

        % perturbação do centro (pequena)
        eps_center = center_var * (2*rand - 1);
        core_center = core_center0 + eps_center * (scale_max - scale_min);

        % perturbação das larguras
        f_ls = 1 + width_var * (2*rand - 1);
        f_lc = 1 + width_var * (2*rand - 1);
        f_rc = 1 + width_var * (2*rand - 1);
        f_rs = 1 + width_var * (2*rand - 1);

        left_support  = max(0, left_support0  * f_ls);
        left_core     = max(0, left_core0     * f_lc);
        right_core    = max(0, right_core0    * f_rc);
        right_support = max(0, right_support0 * f_rs);

        % reconstrói trapézio
        a = core_center - left_support;
        b = core_center - left_core;
        c = core_center + right_core;
        d = core_center + right_support;

        % trunca na escala
        a = max(scale_min, min(scale_max, a));
        b = max(scale_min, min(scale_max, b));
        c = max(scale_min, min(scale_max, c));
        d = max(scale_min, min(scale_max, d));

        % garante ordem interna
        vec = sort([a b c d]);

        % evita núcleo degenerado invertido demais
        if vec(2) > vec(3)
            mid = mean(vec(2:3));
            vec(2) = mid;
            vec(3) = mid;
        end

        TFN_var(i,:) = vec;
    end

    % -----------------------------------------------------
    % AJUSTE DE MONOTONICIDADE ENTRE NÍVEIS
    % Garante que níveis maiores não fiquem "abaixo" dos menores
    % -----------------------------------------------------
    for i = 2:nLevels
        % cada nível i deve ser >= nível anterior em termos de posição
        prev = TFN_var(i-1,:);
        curr = TFN_var(i,:);

        % impõe monotonicidade fraca por componente
        curr(1) = max(curr(1), prev(1));
        curr(2) = max(curr(2), prev(2));
        curr(3) = max(curr(3), prev(3));
        curr(4) = max(curr(4), prev(4));

        % retrunca e reordena
        curr = max(scale_min, min(scale_max, curr));
        curr = sort(curr);

        TFN_var(i,:) = curr;
    end

    % -----------------------------------------------------
    % AJUSTE FINAL:
    % força o último nível a não ultrapassar o máximo
    % e o primeiro a não descer do mínimo
    % -----------------------------------------------------
    TFN_var(1,:) = max(TFN_var(1,:), scale_min);
    TFN_var(end,:) = min(TFN_var(end,:), scale_max);

    for i = 1:nLevels
        TFN_var(i,:) = max(scale_min, min(scale_max, TFN_var(i,:)));
        TFN_var(i,:) = sort(TFN_var(i,:));
    end
end

function val = linguistic2num(x)

    % Trata vazio / missing
    if isempty(x) || (isstring(x) && ismissing(x))
        error('Valor vazio ou missing encontrado na planilha');
    end

    % Se for número
    if isnumeric(x)
        if isnan(x)
            error('Valor NaN encontrado na planilha');
        end
        val = x;
        return;
    end

    % Normaliza texto
    str = lower(strtrim(string(x)));
    if ismissing(str)
        error('Valor inválido (missing) encontrado');
    end
    str = char(str);

    % Mapeamento linguístico → numérico
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
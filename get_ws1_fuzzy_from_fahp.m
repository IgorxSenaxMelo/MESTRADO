function [w_s1_fuzzy, w_s1_crisp, info] = get_ws1_fuzzy_from_fahp(filename)

    [~, sheets] = xlsfinfo(filename);
    abas_interesse = sheets(1:end);

    num_especialistas = length(abas_interesse);
    n = 5;

    matrizes_crisp_all = zeros(n, n, num_especialistas);
    matrizes_fuzzy_all = zeros(n, n, 4, num_especialistas);

    % NOVO: pesos individuais
    w_fuzzy_individual = zeros(n, 4, num_especialistas);
    w_crisp_individual = zeros(n, num_especialistas);

    for s = 1:num_especialistas
        m_crisp = readmatrix(filename, 'Sheet', abas_interesse{s}, 'Range', 'B4:F8');
        matrizes_crisp_all(:,:,s) = m_crisp;

        m_fuzzy = zeros(n, n, 4);
        for i = 1:n
            for j = 1:n
                m_fuzzy(i,j,:) = crisp_to_fuzzy_trap(m_crisp(i,j));
            end
        end

        matrizes_fuzzy_all(:,:,:,s) = m_fuzzy;

        % NOVO: calcular pesos individuais do especialista s
        [w_crisp_s, w_fuzzy_s] = calc_fahp_buckley(m_fuzzy);
        w_fuzzy_individual(:,:,s) = w_fuzzy_s;
        w_crisp_individual(:,s)   = w_crisp_s;
    end

    % Agregação AIJ
    matriz_consensual_fahp = prod(matrizes_fuzzy_all, 4).^(1/num_especialistas);

    % FAHP Buckley do grupo
    [w_s1_crisp, w_s1_fuzzy] = calc_fahp_buckley(matriz_consensual_fahp);

    % Normalização extra de segurança no crisp
    w_s1_crisp = w_s1_crisp / sum(w_s1_crisp);

    % Estrutura de saída
    info.abas_interesse = abas_interesse;
    info.num_especialistas = num_especialistas;
    info.matriz_consensual_fahp = matriz_consensual_fahp;
    info.w_fuzzy_individual = w_fuzzy_individual;
    info.w_crisp_individual = w_crisp_individual;
end

function trap = crisp_to_fuzzy_trap(val)
    escala = [1/9 1/8 1/7 1/6 1/5 1/4 1/3 1/2 1 2 3 4 5 6 7 8 9];
    [~, idx] = min(abs(escala - val));
    v = escala(idx);

    if abs(v-1) < 1e-12
        trap = [1 1 1 1];
    elseif v > 1
        switch v
            case 2, trap = [1 1.5 2.5 3];
            case 3, trap = [2 2.5 3.5 4];
            case 4, trap = [3 3.5 4.5 5];
            case 5, trap = [4 4.5 5.5 6];
            case 6, trap = [5 5.5 6.5 7];
            case 7, trap = [6 6.5 7.5 8];
            case 8, trap = [7 7.5 8.5 9];
            case 9, trap = [8 8.5 9 9];
        end
    else
        v_inv = round(1/v);
        switch v_inv
            case 2, base = [1 1.5 2.5 3];
            case 3, base = [2 2.5 3.5 4];
            case 4, base = [3 3.5 4.5 5];
            case 5, base = [4 4.5 5.5 6];
            case 6, base = [5 5.5 6.5 7];
            case 7, base = [6 6.5 7.5 8];
            case 8, base = [7 7.5 8.5 9];
            case 9, base = [8 8.5 9 9];
        end
        trap = [1/base(4), 1/base(3), 1/base(2), 1/base(1)];
    end
end

function [w_crisp, w_fuzzy] = calc_fahp_buckley(m_fuzzy)
    % m_fuzzy: n x n x 4
    n = size(m_fuzzy,1);
    
    % média geométrica fuzzy de cada linha
    r_i = zeros(n,4);
    for i = 1:n
        prod_row = [1 1 1 1];
        for j = 1:n
            prod_row = prod_row .* squeeze(m_fuzzy(i,j,:))';
        end
        r_i(i,:) = prod_row.^(1/n);
    end
    
    % soma fuzzy das médias geométricas
    sum_r = sum(r_i,1);
    inv_sum_r = [1/sum_r(4), 1/sum_r(3), 1/sum_r(2), 1/sum_r(1)];
    
    % pesos fuzzy
    w_fuzzy = zeros(n,4);
    for i = 1:n
        w_fuzzy(i,:) = r_i(i,:) .* inv_sum_r;
    end
    
    % defuzzificação
    w_crisp = mean(w_fuzzy, 2);
    w_crisp = w_crisp / sum(w_crisp);
end
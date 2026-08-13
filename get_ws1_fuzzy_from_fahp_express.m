function [w_s1_fuzzy,w_s1_crisp,info] = ...
    get_ws1_fuzzy_from_fahp_express(filename)

    [~, sheets] = xlsfinfo(filename);

    abas_interesse = sheets(1:end-1);

    num_especialistas = length(abas_interesse);

    n = 5;

    w_fuzzy_individual = zeros(n,4,num_especialistas);
    w_crisp_individual = zeros(n,num_especialistas);

    for s = 1:num_especialistas

        % =====================================================
        % LEITURA DA PRIMEIRA LINHA
        % =====================================================

        linha_txt = readcell( ...
            filename,...
            'Sheet',abas_interesse{s},...
            'Range','B4:F4');

        linha_ref = zeros(1,n);

        for k = 1:n
            linha_ref(k) = saaty_linguistic2num(linha_txt{k});
        end

        % =====================================================
        % RECONSTRUÇÃO DA MATRIZ AHP
        % =====================================================

        A = zeros(n,n);

        for i = 1:n
            for j = 1:n
                A(i,j) = linha_ref(j) / linha_ref(i);
            end
        end

        % =====================================================
        % MATRIZ FUZZY COMPLETA
        % =====================================================

        m_fuzzy = zeros(n,n,4);

        for i = 1:n
            for j = 1:n
                m_fuzzy(i,j,:) = crisp_to_fuzzy_trap_interp(A(i,j));
            end
        end

        % =====================================================
        % BUCKLEY
        % =====================================================

        [w_crisp,w_fuzzy] = calc_fahp_buckley(m_fuzzy);

        w_fuzzy_individual(:,:,s) = w_fuzzy;
        w_crisp_individual(:,s)   = w_crisp;

    end

    % =====================================================
    % AGREGAÇÃO DO GRUPO
    % =====================================================

    w_s1_fuzzy = mean(w_fuzzy_individual,3);

    w_s1_crisp = mean(w_s1_fuzzy,2);

    w_s1_crisp = w_s1_crisp ./ sum(w_s1_crisp);

    % =====================================================
    % INFO
    % =====================================================

    info.abas_interesse     = abas_interesse;
    info.num_especialistas  = num_especialistas;

    info.w_fuzzy_individual = w_fuzzy_individual;
    info.w_crisp_individual = w_crisp_individual;

end

%% =====================================================================
function trap = crisp_to_fuzzy_trap_interp(x)

    % Escala trapezoidal adotada
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

    % =====================================================
    % Verificação
    % =====================================================

    if ~isscalar(x) || ~isfinite(x) || x <= 0
        error('O valor de comparação deve ser positivo e finito.');
    end

    % Como os julgamentos de referência estão entre 1 e 9,
    % os quocientes reconstruídos devem permanecer entre 1/9 e 9.
    if x < 1/9 - 1e-12 || x > 9 + 1e-12
        error('Valor reconstruído fora da escala Saaty: %.6f', x);
    end

    % =====================================================
    % Igualdade
    % =====================================================

    if abs(x - 1) < 1e-12

        trap = [1 1 1 1];
        return;

    end

    % =====================================================
    % Comparações recíprocas: x < 1
    %
    % NÃO interpolar diretamente no domínio recíproco.
    % Fuzzifica 1/x e calcula o inverso fuzzy exato.
    % =====================================================

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

    % =====================================================
    % Valores x >= 1
    % =====================================================

    % Valor exatamente presente na escala
    if abs(x - round(x)) < 1e-12

        k = round(x);
        trap = scale(k,2:5);
        return;

    end

    % =====================================================
    % Interpolação linear para valores intermediários > 1
    % =====================================================

    lower = floor(x);
    upper = ceil(x);

    alpha = ...
        (x - lower) / ...
        (upper - lower);

    trap = ...
        (1-alpha)*scale(lower,2:5) + ...
        alpha*scale(upper,2:5);

end

%% =====================================================================
function [w_crisp,w_fuzzy] = calc_fahp_buckley(m_fuzzy)

    n = size(m_fuzzy,1);

    % =====================================
    % Média geométrica fuzzy (Buckley)
    % =====================================

    r = zeros(n,4);

    for i = 1:n

        prod_row = [1 1 1 1];

        for j = 1:n
            prod_row = prod_row .* squeeze(m_fuzzy(i,j,:))';
        end

        r(i,:) = prod_row.^(1/n);

    end

    % =====================================
    % Soma das médias geométricas
    % =====================================

    sum_r = sum(r,1);

    inv_sum = [ ...
        1/sum_r(4)
        1/sum_r(3)
        1/sum_r(2)
        1/sum_r(1)]';

    % =====================================
    % Pesos fuzzy
    % =====================================

    w_fuzzy = zeros(n,4);

    for i = 1:n
        w_fuzzy(i,:) = r(i,:) .* inv_sum;
    end

    % =====================================
    % Defuzzificação
    % =====================================

    w_crisp = mean(w_fuzzy,2);

    w_crisp = w_crisp ./ sum(w_crisp);

end

%% =====================================================================
function val = saaty_linguistic2num(x)

    if ismissing(x)
        val = NaN;
        return
    end

    x = lower(strtrim(string(x)));

    switch x

        case "igual importância"
            val = 1;

        case "fracamente mais importante"
            val = 2;

        case "moderadamente mais importante"
            val = 3;

        case "moderadamente a fortemente mais importante"
            val = 4;

        case "fortemente mais importante"
            val = 5;

        case "fortemente a muito fortemente mais importante"
            val = 6;

        case "muito fortemente mais importante"
            val = 7;

        case "muito fortemente a extremamente mais importante"
            val = 8;

        case "extremamente mais importante"
            val = 9;

        otherwise
            error('Escala Saaty não reconhecida: %s', x);

    end

end
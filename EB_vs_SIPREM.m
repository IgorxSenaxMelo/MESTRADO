%% =========================================================
% COMPARAÇÃO ENTRE A CLASSIFICAÇÃO DO GT E A CLASSIFICAÇÃO DO EB
%
% Saída:
%   Comparacao_Classificacao_GT_EB.xlsx
%
% Abas:
%   1. Comparacao_Geral
%   2. Resumo_Classes
%   3. Divergencias_Criticas
%% =========================================================

arquivo_comparacao = 'Comparacao_Classificacao_GT_EB.xlsx';

%% ---------------------------------------------------------
% 1. DESCRIÇÕES DOS REQUISITOS DO EB
%% ---------------------------------------------------------

descricao_eb = [
"Possuir como armamento principal obuseiro com tubo de alma raiada e calibre 105 mm."
"Possuir tubo de comprimento igual ou superior a 30 vezes a medida do calibre."
"Possuir, ao utilizar munição convencional de artilharia, condições de bater alvos com no mínimo 11 km de alcance."
"Possuir, ao utilizar munição especial de artilharia, condições de bater alvos com no mínimo 17 km de alcance."
"Possuir cadência de tiro normal de 3 tiros por minuto e cadência máxima de, no mínimo, 6 tiros por minuto."
"Possibilitar o disparo, sem mudança de pontaria, em setor de tiro de, no mínimo, 200 milésimos."
"Possibilitar o carregamento do obuseiro de forma manual em qualquer elevação."
"Possuir capacidade de ser tracionado por viatura adotada pelo EB, com mobilidade tática em terrenos sem restrição ao movimento para tropa leve."
"Possibilitar ser tracionado por viatura capaz de transportar toda a guarnição, bagagens, palamentas e equipamentos necessários."
"Possuir condições de ser transportado em embarcações orgânicas do Exército Brasileiro e da Marinha do Brasil."
"Possuir condições de ser embarcado em aeronaves de transporte orgânicas da Força Aérea Brasileira."
"Realizar pontaria das peças e pontaria recíproca de forma manual, com uso de lunetas, em caso de falha do sistema automático."
"Possuir condições de realizar pontaria das peças de forma manual, com uso de lunetas, à noite."
"Possuir radar de medição instantânea da velocidade inicial acoplado ao armamento."
"Possuir capacidade de utilizar munição de 105 mm no padrão da OTAN."
"Possuir condições de executar diversos tipos e métodos de tiro, com diferentes tipos de granadas e espoletas."
"Entrar em posição e realizar o disparo em menos de 4 minutos."
"Sair de posição após o disparo em até 2 minutos."
"Ser operado e permitir manutenção orgânica sob quaisquer condições climáticas, de dia e de noite."
"Possuir tubo de comprimento igual ou superior a 37 vezes a medida do calibre."
"Possibilitar o disparo, sem mudança de pontaria, em setor de tiro de 6.400 milésimos ou 360 graus."
"Possuir capacidade de ser transportado por aeronave de asa rotativa."
"Possuir capacidade de, se necessário, ser lançado por paraquedas utilizado pelo Exército Brasileiro."
"Possuir capacidade de, se necessário, ser embarcado em viatura sobre rodas para transporte."
"Possuir capacidade de ser desmontado e transportado em embarcações do Exército para o ambiente operacional amazônico."
"Possuir dispositivo para pontaria automática e independente, com busca do norte verdadeiro e inserção manual de dados."
"Possuir interface para recebimento criptografado de dados de pontaria e elementos de tiro."
"Possuir sistema de navegação inercial integrado ao GPS e capacidade de transmitir dados da posição e das condições da peça."
"Poder executar tiros com munições especiais de artilharia de 105 mm no padrão da OTAN."
"Entrar em posição e realizar o disparo em menos de 3 minutos, quando operado por guarnição adestrada."
"Sair de posição após o disparo em até 1 minuto e 30 segundos, quando operado por guarnição adestrada."
"Possuir redes de camuflagem com proteção visual, térmica e contra detecção radar."
"Possuir meios de simulação que permitam o treinamento dos operadores em português."
"Realizar a capacitação dos operadores, incluindo cursos e instruções sobre os conceitos de operação do material."
"Realizar a capacitação dos operadores e das equipes de manutenção no Brasil."
];

%% ---------------------------------------------------------
% 2. IDENTIFICAÇÃO DO EB: ROA OU ROD
%% ---------------------------------------------------------

% Os primeiros 19 requisitos são ROA.
% Os 16 requisitos seguintes são ROD.

classe_eb = [
    repmat("ROA",19,1)
    repmat("ROD",16,1)
];

%% ---------------------------------------------------------
% 3. PESOS ATRIBUÍDOS PELO EB
%% ---------------------------------------------------------

peso_eb = [
    10  % ROA 1
    10  % ROA 2
    10  % ROA 3
    10  % ROA 4
    10  % ROA 5
    10  % ROA 6
    10  % ROA 7
    10  % ROA 8
    10  % ROA 9
     8  % ROA 10
    10  % ROA 11
    10  % ROA 12
     8  % ROA 13
     8  % ROA 14
     9  % ROA 15
    10  % ROA 16
     9  % ROA 17
    10  % ROA 18
     9  % ROA 19
     7  % ROD 1
     6  % ROD 2
     6  % ROD 3
     6  % ROD 4
     6  % ROD 5
     5  % ROD 6
     6  % ROD 7
     6  % ROD 8
     6  % ROD 9
     6  % ROD 10
     6  % ROD 11
     6  % ROD 12
     6  % ROD 13
     6  % ROD 14
     6  % ROD 15
     6  % ROD 16
];

%% ---------------------------------------------------------
% 4. IDENTIFICAÇÃO DOS REQUISITOS
%% ---------------------------------------------------------

n_requisitos_eb = numel(descricao_eb);

if nReq ~= n_requisitos_eb
    error(['O script encontrou %d requisitos, mas a lista do EB possui %d. ' ...
           'Verifique a correspondência entre as linhas da planilha e a lista do EB.'], ...
           nReq, n_requisitos_eb);
end

% Identificação completa usada pelo EB
identificacao_eb = [
    "ROA 1"
    "ROA 2"
    "ROA 3"
    "ROA 4"
    "ROA 5"
    "ROA 6"
    "ROA 7"
    "ROA 8"
    "ROA 9"
    "ROA 10"
    "ROA 11"
    "ROA 12"
    "ROA 13"
    "ROA 14"
    "ROA 15"
    "ROA 16"
    "ROA 17"
    "ROA 18"
    "ROA 19"
    "ROD 1"
    "ROD 2"
    "ROD 3"
    "ROD 4"
    "ROD 5"
    "ROD 6"
    "ROD 7"
    "ROD 8"
    "ROD 9"
    "ROD 10"
    "ROD 11"
    "ROD 12"
    "ROD 13"
    "ROD 14"
    "ROD 15"
    "ROD 16"
];

%% ---------------------------------------------------------
% 5. PADRONIZAÇÃO DAS CATEGORIAS DO GT
%% ---------------------------------------------------------

classe_gt_original = string(cat(:));
classe_gt = strings(nReq,1);

for i = 1:nReq

    texto_classe = lower(strtrim(classe_gt_original(i)));

    if texto_classe == "key"
        classe_gt(i) = "KEY";

    elseif texto_classe == "g1" || ...
           texto_classe == "grupo 1" || ...
           texto_classe == "grupo1"

        classe_gt(i) = "G1";

    elseif texto_classe == "g2" || ...
           texto_classe == "grupo 2" || ...
           texto_classe == "grupo2"

        classe_gt(i) = "G2";

    elseif texto_classe == "g3" || ...
           texto_classe == "grupo 3" || ...
           texto_classe == "grupo3"

        classe_gt(i) = "G3";

    else
        classe_gt(i) = upper(classe_gt_original(i));
    end
end

%% ---------------------------------------------------------
% 6. PRIMEIRA ABA: COMPARAÇÃO GERAL
%% ---------------------------------------------------------

T_comparacao = table( ...
    rank_s2(:), ...
    string(req_labels(:)), ...
    identificacao_eb(:), ...
    descricao_eb(:), ...
    classe_gt(:), ...
    classe_eb(:), ...
    peso_eb(:), ...
    phi_net(:), ...
    'VariableNames', { ...
        'Rank_SIPREM', ...
        'Requisito_SIPREM', ...
        'Requisito_EB', ...
        'Descricao', ...
        'Classe_SIPREM', ...
        'Classe_EB', ...
        'Peso_EB', ...
        'Phi_Liquido'});

T_comparacao = sortrows( ...
    T_comparacao, ...
    'Rank_SIPREM', ...
    'ascend');

%% ---------------------------------------------------------
% 7. SEGUNDA ABA: RESUMO DAS CLASSES
%% ---------------------------------------------------------

classes_analisadas = ["KEY"; "G1"; "G2"; "G3"];

quant_roa = zeros(4,1);
quant_rod = zeros(4,1);
quant_total = zeros(4,1);

for i = 1:numel(classes_analisadas)

    classe_atual = classes_analisadas(i);

    quant_roa(i) = sum( ...
        classe_gt == classe_atual & classe_eb == "ROA");

    quant_rod(i) = sum( ...
        classe_gt == classe_atual & classe_eb == "ROD");

    quant_total(i) = quant_roa(i) + quant_rod(i);
end

interpretacao = [
"Requisitos classificados como essenciais pelo GT. A presença de ROD nessa classe indica que capacidades desejáveis foram consideradas indispensáveis pela análise."
"Requisitos de alta relevância, reunindo capacidades fundamentais e requisitos de apoio com elevada contribuição para a missão."
"Requisitos de relevância intermediária, relacionados principalmente a capacidades complementares e incrementais."
"Requisitos de menor prioridade relativa. A presença de ROA nesta classe representa uma divergência importante em relação à classificação do EB."
];

T_resumo_classes = table( ...
    classes_analisadas, ...
    quant_roa, ...
    quant_rod, ...
    quant_total, ...
    interpretacao, ...
    'VariableNames', { ...
        'Classe', ...
        'ROA', ...
        'ROD', ...
        'Total', ...
        'Interpretacao'});

% Linha de totalização
total_roa = sum(classe_eb == "ROA");
total_rod = sum(classe_eb == "ROD");
total_geral = total_roa + total_rod;

texto_total = sprintf( ...
    ['Há predominância de requisitos operacionais absolutos: ' ...
     '%d ROA (%.2f%%) e %d ROD (%.2f%%).'], ...
    total_roa, 100*total_roa/total_geral, ...
    total_rod, 100*total_rod/total_geral);

T_total_classes = table( ...
    "Total", ...
    total_roa, ...
    total_rod, ...
    total_geral, ...
    string(texto_total), ...
    'VariableNames', T_resumo_classes.Properties.VariableNames);

T_resumo_classes = [T_resumo_classes; T_total_classes];

%% ---------------------------------------------------------
% 8. RESUMO: ESSENCIAIS E COMPLEMENTARES
%% ---------------------------------------------------------

quant_essenciais = sum( ...
    classe_gt == "KEY" | classe_gt == "G1");

quant_complementares = sum( ...
    classe_gt == "G2" | classe_gt == "G3");

percent_essenciais = 100 * quant_essenciais / nReq;
percent_complementares = 100 * quant_complementares / nReq;

T_resumo_grupos = table( ...
    ["Essenciais (KEY+G1)"; "Complementares (G2+G3)"], ...
    [quant_essenciais; quant_complementares], ...
    [percent_essenciais; percent_complementares], ...
    'VariableNames', { ...
        'Grupo', ...
        'Quantidade', ...
        'Percentual'});
%% ---------------------------------------------------------
% CRUZAMENTOS ENTRE AS CLASSES DO SIPREM E DO EB
% ---------------------------------------------------------

% ROD classificados como G1 pelo SIPREM
idx_rod_g1 = ...
    classe_eb == "ROD" & classe_gt == "G1";

% ROA classificados como G2 pelo SIPREM
idx_roa_g2 = ...
    classe_eb == "ROA" & classe_gt == "G2";

% ROD classificados como KEY pelo SIPREM
idx_rod_key = ...
    classe_eb == "ROD" & classe_gt == "KEY";

% ROA classificados como G3 pelo SIPREM
idx_roa_g3 = ...
    classe_eb == "ROA" & classe_gt == "G3";

%% Tabela-resumo dos cruzamentos

Cruzamento = [
    "ROD classificado como KEY"
    "ROD classificado como G1"
    "ROA classificado como G2"
    "ROA classificado como G3"
];

Quantidade = [
    sum(idx_rod_key)
    sum(idx_rod_g1)
    sum(idx_roa_g2)
    sum(idx_roa_g3)
];

Interpretacao_Cruzamento = [
    "Requisito desejável para o EB considerado essencial pelo SIPREM."
    "Requisito desejável para o EB considerado de alta prioridade pelo SIPREM."
    "Requisito absoluto para o EB classificado como prioridade intermediária pelo SIPREM."
    "Requisito absoluto para o EB classificado como baixa prioridade relativa pelo SIPREM."
];

T_resumo_cruzamentos = table( ...
    Cruzamento, ...
    Quantidade, ...
    Interpretacao_Cruzamento, ...
    'VariableNames', { ...
        'Cruzamento_EB_SIPREM', ...
        'Quantidade', ...
        'Interpretacao'});

%% ---------------------------------------------------------
% LISTA DOS REQUISITOS NOS CRUZAMENTOS RELEVANTES
% ---------------------------------------------------------

idx_cruzamentos = ...
    idx_rod_key | ...
    idx_rod_g1 | ...
    idx_roa_g2 | ...
    idx_roa_g3;

tipo_cruzamento = strings(nReq,1);

tipo_cruzamento(idx_rod_key) = ...
    "ROD no EB e KEY no SIPREM";

tipo_cruzamento(idx_rod_g1) = ...
    "ROD no EB e G1 no SIPREM";

tipo_cruzamento(idx_roa_g2) = ...
    "ROA no EB e G2 no SIPREM";

tipo_cruzamento(idx_roa_g3) = ...
    "ROA no EB e G3 no SIPREM";

T_lista_cruzamentos = table( ...
    rank_s2(:), ...
    string(req_labels(:)), ...
    identificacao_eb(:), ...
    descricao_eb(:), ...
    classe_gt(:), ...
    classe_eb(:), ...
    tipo_cruzamento(:), ...
    'VariableNames', { ...
        'Rank_SIPREM', ...
        'Requisito_SIPREM', ...
        'Requisito_EB', ...
        'Descricao', ...
        'Classe_SIPREM', ...
        'Classe_EB', ...
        'Cruzamento'});

% Mantém apenas os quatro cruzamentos relevantes
T_lista_cruzamentos = ...
    T_lista_cruzamentos(idx_cruzamentos,:);

T_lista_cruzamentos = sortrows( ...
    T_lista_cruzamentos, ...
    {'Classe_SIPREM','Rank_SIPREM'}, ...
    {'ascend','ascend'});

%% ---------------------------------------------------------
% 9. TERCEIRA ABA: DIVERGÊNCIAS CRÍTICAS
%% ---------------------------------------------------------

% Divergência crítica 1:
% requisito desejável do EB classificado como KEY pelo GT
div_key_rod = classe_gt == "KEY" & classe_eb == "ROD";

% Divergência crítica 2:
% requisito absoluto do EB classificado como G3 pelo GT
div_g3_roa = classe_gt == "G3" & classe_eb == "ROA";

divergencia_critica = div_key_rod | div_g3_roa;

tipo_divergencia = strings(nReq,1);
interpretacao_divergencia = strings(nReq,1);

tipo_divergencia(div_key_rod) = ...
    "ROD no EB e KEY no GT";

interpretacao_divergencia(div_key_rod) = ...
    "O GT considerou essencial um requisito classificado pelo EB como desejável.";

tipo_divergencia(div_g3_roa) = ...
    "ROA no EB e G3 no GT";

interpretacao_divergencia(div_g3_roa) = ...
    "O GT atribuiu baixa prioridade relativa a um requisito considerado absoluto pelo EB.";

T_divergencias = table( ...
    rank_s2(:), ...
    string(req_labels(:)), ...
    identificacao_eb(:), ...
    descricao_eb(:), ...
    classe_gt(:), ...
    classe_eb(:), ...
    peso_eb(:), ...
    phi_net(:), ...
    tipo_divergencia(:), ...
    interpretacao_divergencia(:), ...
    'VariableNames', { ...
        'Rank_GT', ...
        'Requisito_GT', ...
        'Requisito_EB', ...
        'Descricao', ...
        'Classe_GT', ...
        'Classe_EB', ...
        'Peso_EB', ...
        'Phi_Liquido', ...
        'Tipo_Divergencia', ...
        'Interpretacao'});

% Mantém apenas as divergências críticas
T_divergencias = T_divergencias(divergencia_critica,:);

% Ordena pelo ranking do GT
T_divergencias = sortrows(T_divergencias,'Rank_GT','ascend');

%% ---------------------------------------------------------
% 10. EXPORTAÇÃO PARA EXCEL
%% ---------------------------------------------------------

if isfile(arquivo_comparacao)
    try
        delete(arquivo_comparacao);
    catch
        error(['Não foi possível substituir o arquivo. ' ...
               'Feche-o no Excel e execute novamente.']);
    end
end

% Primeira aba
writetable( ...
    T_comparacao, ...
    arquivo_comparacao, ...
    'Sheet','Comparacao_Geral');

%% ---------------------------------------------------------
% SEGUNDA ABA: RESUMOS E CRUZAMENTOS
% ---------------------------------------------------------

% Tabela principal: distribuição ROA e ROD por classe SIPREM
writetable( ...
    T_resumo_classes, ...
    arquivo_comparacao, ...
    'Sheet','Resumo_Classes', ...
    'Range','A1');

% Essenciais versus complementares
writetable( ...
    T_resumo_grupos, ...
    arquivo_comparacao, ...
    'Sheet','Resumo_Classes', ...
    'Range','A9');

% Resumo quantitativo dos cruzamentos relevantes
writetable( ...
    T_resumo_cruzamentos, ...
    arquivo_comparacao, ...
    'Sheet','Resumo_Classes', ...
    'Range','A14');
%%
%% ---------------------------------------------------------
% TERCEIRA ABA: DIVERGÊNCIAS CRÍTICAS
%% ---------------------------------------------------------

% ROD no EB e KEY no SIPREM
div_key_rod = ...
    classe_gt == "KEY" & classe_eb == "ROD";

% ROA no EB e G3 no SIPREM
div_g3_roa = ...
    classe_gt == "G3" & classe_eb == "ROA";

% União das divergências críticas
divergencia_critica = ...
    div_key_rod | div_g3_roa;

% Inicialização das colunas de texto
tipo_divergencia = strings(nReq,1);
interpretacao_divergencia = strings(nReq,1);

% Preenchimento dos textos
tipo_divergencia(div_key_rod) = ...
    "ROD no EB e KEY no SIPREM";

interpretacao_divergencia(div_key_rod) = ...
    "O SIPREM classificou como essencial um requisito considerado desejável pelo EB.";

tipo_divergencia(div_g3_roa) = ...
    "ROA no EB e G3 no SIPREM";

interpretacao_divergencia(div_g3_roa) = ...
    "O SIPREM atribuiu baixa prioridade relativa a um requisito considerado absoluto pelo EB.";

% Criação da tabela
T_divergencias = table( ...
    rank_s2(:), ...
    string(req_labels(:)), ...
    identificacao_eb(:), ...
    descricao_eb(:), ...
    classe_gt(:), ...
    classe_eb(:), ...
    peso_eb(:), ...
    phi_net(:), ...
    tipo_divergencia(:), ...
    interpretacao_divergencia(:), ...
    'VariableNames', { ...
        'Rank_SIPREM', ...
        'Requisito_SIPREM', ...
        'Requisito_EB', ...
        'Descricao', ...
        'Classe_SIPREM', ...
        'Classe_EB', ...
        'Peso_EB', ...
        'Phi_Liquido', ...
        'Tipo_Divergencia', ...
        'Interpretacao'});

% Mantém somente as divergências críticas
T_divergencias = ...
    T_divergencias(divergencia_critica,:);

% Ordena pelo ranking SIPREM
T_divergencias = sortrows( ...
    T_divergencias, ...
    'Rank_SIPREM', ...
    'ascend');

%% ---------------------------------------------------------
% 11. RESULTADOS NO COMMAND WINDOW
%% ---------------------------------------------------------

fprintf('\n====================================================\n');
fprintf('COMPARAÇÃO GT × EB EXPORTADA COM SUCESSO\n');
fprintf('====================================================\n');
fprintf('Arquivo: %s\n', arquivo_comparacao);
fprintf('Total de requisitos: %d\n', nReq);
fprintf('ROA: %d\n', total_roa);
fprintf('ROD: %d\n', total_rod);
fprintf('Divergências críticas: %d\n', height(T_divergencias));

disp(' ');
disp('--- RESUMO DAS CLASSES ---');
disp(T_resumo_classes);

disp(' ');
disp('--- DIVERGÊNCIAS CRÍTICAS ---');

if isempty(T_divergencias)
    disp('Nenhuma divergência crítica identificada.');
else
    disp(T_divergencias);
end
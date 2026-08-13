%% =============================================================
% GROUP-LEVEL COMPARISON:
% CONVENTIONAL BUCKLEY FAHP vs FAHP-EXPRESS
%
% Reads ALL worksheets in AHP_NOVO.xlsx.
%
% Conventional Buckley FAHP:
%   - uses the complete 5x5 pairwise-comparison matrix
%   - direct judgments are read from the upper triangular portion
%   - reciprocal lower-triangular values are reconstructed exactly
%
% FAHP-Express:
%   - uses only the first row (reference criterion)
%   - reconstructs a_ij = a_ref,j / a_ref,i
%   - intermediate values > 1 are fuzzified by linear interpolation
%   - values < 1 are obtained by exact fuzzy reciprocity
%
% Group aggregation:
%   - individual fuzzy weights are aggregated by arithmetic mean
%   - aggregated fuzzy weights are defuzzified by the vertex mean
%   - crisp group weights are normalized to sum to 1
%
% Outputs:
%   Table 3 - group crisp weights and differences
%   Table 4 - fuzzy-width/area/distance comparison
%   Individual - individual crisp weights and CR
%   Group_Fuzzy - aggregated trapezoidal fuzzy weights
%
% MATLAB R2019b+ recommended
%% =============================================================

clear;
clc;
close all;

format long g;

%% =============================================================
% 1. SETTINGS
%% =============================================================

filename = 'AHP_NOVO.xlsx';

criteria = {
    'Mission Impact'
    'Cost'
    'Technical Risk'
    'Schedule'
    'Verification Risk'
};

n = numel(criteria);

% Read every worksheet
sheets = sheetnames(filename);
nExperts = numel(sheets);

fprintf('\n============================================================\n');
fprintf('FAHP vs FAHP-EXPRESS - GROUP COMPARISON\n');
fprintf('============================================================\n');
fprintf('File: %s\n', filename);
fprintf('Worksheets / experts: %d\n', nExperts);
fprintf('Criteria: %d\n', n);

%% =============================================================
% 2. STORAGE
%% =============================================================

Wf_full_ind = zeros(n,4,nExperts);
Wf_expr_ind = zeros(n,4,nExperts);

Wc_full_ind = zeros(n,nExperts);
Wc_expr_ind = zeros(n,nExperts);

CR_ind = zeros(nExperts,1);

reference_rows = zeros(nExperts,n);

%% =============================================================
% 3. PROCESS ALL WORKSHEETS
%% =============================================================

for s = 1:nExperts

    sheetName = sheets{s};

    fprintf('\nProcessing %s (%d/%d)...\n', ...
        sheetName, s, nExperts);

    %% ---------------------------------------------------------
    % 3.1 Read conventional full AHP matrix
    %
    % Only the UPPER TRIANGLE is treated as independent input.
    % Lower-triangular entries are reconstructed as reciprocals.
    %
    % Spreadsheet range:
    % B4:F8 = 5x5 pairwise-comparison matrix
    %% ---------------------------------------------------------

    raw = readcell( ...
        filename, ...
        'Sheet', sheetName, ...
        'Range', 'B4:F8');

    A_full = eye(n);

    for i = 1:n

        for j = i+1:n

            value = parseSaatyCell(raw{i,j});

            if ~isfinite(value) || value <= 0
                error( ...
                    'Invalid judgment in sheet %s, matrix position (%d,%d).', ...
                    sheetName,i,j);
            end

            if value < 1/9 - 1e-12 || value > 9 + 1e-12
                error( ...
                    'Judgment outside Saaty range in sheet %s: %.6f.', ...
                    sheetName,value);
            end

            A_full(i,j) = value;
            A_full(j,i) = 1/value;

        end
    end

    %% ---------------------------------------------------------
    % 3.2 Conventional matrix consistency
    %% ---------------------------------------------------------

    CR_ind(s) = calculateCR(A_full);

    %% ---------------------------------------------------------
    % 3.3 Conventional Buckley FAHP
    %% ---------------------------------------------------------

    F_full = fuzzifyMatrixReciprocal(A_full);

    [wc_full,wf_full] = buckleyWeights(F_full);

    Wc_full_ind(:,s)   = wc_full;
    Wf_full_ind(:,:,s) = wf_full;

    %% ---------------------------------------------------------
    % 3.4 FAHP-Express
    %
    % The first criterion is the reference.
    % The reference row is exactly the first row of A_full.
    %% ---------------------------------------------------------

    referenceRow = A_full(1,:);
    reference_rows(s,:) = referenceRow;

    A_expr = reconstructExpress(referenceRow);

    % A_expr is perfectly reciprocal/transitive in the crisp domain.
    F_expr = fuzzifyMatrixReciprocal(A_expr);

    [wc_expr,wf_expr] = buckleyWeights(F_expr);

    Wc_expr_ind(:,s)   = wc_expr;
    Wf_expr_ind(:,:,s) = wf_expr;

    %% ---------------------------------------------------------
    % 3.5 Audit fuzzy reciprocity
    %% ---------------------------------------------------------

    assertFuzzyReciprocity(F_full, 1e-10, ...
        sprintf('%s - Full',sheetName));

    assertFuzzyReciprocity(F_expr, 1e-10, ...
        sprintf('%s - Express',sheetName));

end

%% =============================================================
% 4. GROUP AGGREGATION
%% =============================================================

% Arithmetic aggregation of fuzzy weights across experts
Wf_full_group = mean(Wf_full_ind,3);
Wf_expr_group = mean(Wf_expr_ind,3);

% Defuzzify aggregated fuzzy weights by vertex mean
Wc_full_group = mean(Wf_full_group,2);
Wc_expr_group = mean(Wf_expr_group,2);

% Normalize crisp group weights
Wc_full_group = Wc_full_group / sum(Wc_full_group);
Wc_expr_group = Wc_expr_group / sum(Wc_expr_group);

%% =============================================================
% 5. TABLE 3 - GROUP-LEVEL CRISP WEIGHTS
%% =============================================================

difference = Wc_expr_group - Wc_full_group;

relativeDifference = ...
    100 * difference ./ Wc_full_group;

absDifference = abs(difference);
absRelativeDifference = abs(relativeDifference);

Table3 = table( ...
    criteria, ...
    Wc_full_group, ...
    Wc_expr_group, ...
    difference, ...
    relativeDifference, ...
    absDifference, ...
    absRelativeDifference, ...
    'VariableNames', { ...
        'Criteria', ...
        'Buckley', ...
        'Express', ...
        'Difference_ExpressMinusBuckley', ...
        'RelativeDifference_Percent', ...
        'AbsoluteDifference', ...
        'AbsoluteRelativeDifference_Percent'});

fprintf('\n\n============================================================\n');
fprintf('TABLE 3 - GROUP-LEVEL COMPARISON OF CRITERIA WEIGHTS\n');
fprintf('============================================================\n');
disp(Table3);

%% =============================================================
% 6. TABLE 4 - FUZZY WEIGHT PRESERVATION
%
% Support width = u-l
% Core width    = n-m
% Area          = [(u-l)+(n-m)]/2
% Euclidean distance between the four vertices
%% =============================================================

supportFull = ...
    Wf_full_group(:,4) - Wf_full_group(:,1);

supportExpr = ...
    Wf_expr_group(:,4) - Wf_expr_group(:,1);

coreFull = ...
    Wf_full_group(:,3) - Wf_full_group(:,2);

coreExpr = ...
    Wf_expr_group(:,3) - Wf_expr_group(:,2);

areaFull = ...
    (supportFull + coreFull)/2;

areaExpr = ...
    (supportExpr + coreExpr)/2;

euclideanDistance = ...
    sqrt(sum((Wf_full_group-Wf_expr_group).^2,2));

supportPreservation = ...
    100 * (1 - abs(supportFull-supportExpr) ./ max(supportFull,eps));

corePreservation = ...
    100 * (1 - abs(coreFull-coreExpr) ./ max(coreFull,eps));

areaPreservation = ...
    100 * (1 - abs(areaFull-areaExpr) ./ max(areaFull,eps));

% Avoid negative preservation percentages
supportPreservation = max(supportPreservation,0);
corePreservation    = max(corePreservation,0);
areaPreservation    = max(areaPreservation,0);

Table4 = table( ...
    criteria, ...
    supportFull, ...
    supportExpr, ...
    coreFull, ...
    coreExpr, ...
    areaFull, ...
    areaExpr, ...
    euclideanDistance, ...
    supportPreservation, ...
    corePreservation, ...
    areaPreservation, ...
    'VariableNames', { ...
        'Criteria', ...
        'SupportWidth_Buckley', ...
        'SupportWidth_Express', ...
        'CoreWidth_Buckley', ...
        'CoreWidth_Express', ...
        'Area_Buckley', ...
        'Area_Express', ...
        'EuclideanDistance', ...
        'SupportPreservation_Percent', ...
        'CorePreservation_Percent', ...
        'AreaPreservation_Percent'});

fprintf('\n============================================================\n');
fprintf('TABLE 4 - GROUP-LEVEL PRESERVATION OF FUZZY WEIGHTS\n');
fprintf('============================================================\n');
disp(Table4);

%% =============================================================
% 7. AGGREGATED FUZZY WEIGHTS - AUDIT TABLE
%% =============================================================

GroupFuzzy = table( ...
    criteria, ...
    Wf_full_group(:,1), ...
    Wf_full_group(:,2), ...
    Wf_full_group(:,3), ...
    Wf_full_group(:,4), ...
    Wf_expr_group(:,1), ...
    Wf_expr_group(:,2), ...
    Wf_expr_group(:,3), ...
    Wf_expr_group(:,4), ...
    'VariableNames', { ...
        'Criteria', ...
        'Buckley_l', ...
        'Buckley_m', ...
        'Buckley_n', ...
        'Buckley_u', ...
        'Express_l', ...
        'Express_m', ...
        'Express_n', ...
        'Express_u'});

%% =============================================================
% 8. INDIVIDUAL AUDIT TABLE
%% =============================================================

sheetColumn = string(sheets(:));

Individual = table( ...
    sheetColumn, ...
    CR_ind, ...
    'VariableNames', {'Sheet','CR'});

for k = 1:n

    vnameFull = matlab.lang.makeValidName( ...
        ['Buckley_' criteria{k}]);

    vnameExpr = matlab.lang.makeValidName( ...
        ['Express_' criteria{k}]);

    Individual.(vnameFull) = Wc_full_ind(k,:)';
    Individual.(vnameExpr) = Wc_expr_ind(k,:)';

end

fprintf('\n============================================================\n');
fprintf('INDIVIDUAL CONSISTENCY SUMMARY\n');
fprintf('============================================================\n');

fprintf('Mean CR   = %.4f\n', mean(CR_ind));
fprintf('Median CR = %.4f\n', median(CR_ind));
fprintf('Max CR    = %.4f\n', max(CR_ind));
fprintf('CR < 0.10 = %d/%d experts\n', sum(CR_ind < 0.10), nExperts);

%% =============================================================
% 9. GLOBAL AGREEMENT METRICS
%% =============================================================

MAE_group = mean(abs(Wc_full_group-Wc_expr_group));
RMSE_group = sqrt(mean((Wc_full_group-Wc_expr_group).^2));

rankFull = getRanks(Wc_full_group);
rankExpr = getRanks(Wc_expr_group);

spearmanGroup = corr( ...
    rankFull, ...
    rankExpr, ...
    'Type','Spearman');

fprintf('\n============================================================\n');
fprintf('GLOBAL GROUP-LEVEL AGREEMENT\n');
fprintf('============================================================\n');

fprintf('MAE       = %.6f\n', MAE_group);
fprintf('RMSE      = %.6f\n', RMSE_group);
fprintf('Spearman  = %.6f\n', spearmanGroup);


%% =============================================================
% 10. FIGURE 2 - GROUP-LEVEL TRAPEZOIDAL FUZZY WEIGHTS
%% =============================================================

figure('Color','w','Position',[80 80 1250 720], ...
    'Name','Figure_2_Group_Fuzzy_Weights');

for k = 1:n

    subplot(2,3,k);

    tB = Wf_full_group(k,:);
    tE = Wf_expr_group(k,:);

    [xB,yB] = trapezoidXY(tB);
    [xE,yE] = trapezoidXY(tE);

    hold on;

    fill(xB,yB,[0.30 0.40 1.00], ...
        'FaceAlpha',0.35, ...
        'EdgeColor',[0.20 0.30 0.90], ...
        'LineWidth',1.1);

    fill(xE,yE,[1.00 0.35 0.35], ...
        'FaceAlpha',0.35, ...
        'EdgeColor',[0.90 0.20 0.20], ...
        'LineWidth',1.1);

    title(criteria{k},'FontWeight','bold');
    ylim([0 1.08]);
    ylabel('\mu(x)');
    grid on;
    box on;

    xmin = min([tB(1),tE(1)]);
    xmax = max([tB(4),tE(4)]);
    margem = max(0.02*(xmax-xmin),1e-4);
    xlim([xmin-margem xmax+margem]);

    if k == n
        legend({'Buckley','Express'},'Location','best');
    end

    hold off;
end

sgtitle('Comparison of Group-Level Trapezoidal Fuzzy Weights', ...
    'FontWeight','bold');

exportgraphics(gcf,'Figure_2_Group_Fuzzy_Weights.png','Resolution',300);
exportgraphics(gcf,'Figure_2_Group_Fuzzy_Weights.pdf','ContentType','vector');


%% =============================================================
% 11. TABLE 5 - INDIVIDUAL-LEVEL PRESERVATION
%
% Relative Euclidean distance:
%   100 * ||w_B - w_E||_2 / ||w_B||_2
%
% Preservation of support/core/area:
%   100 * [1 - |Measure_B - Measure_E| / Measure_B]
%
% Values are calculated for each expert and criterion first,
% and then summarized across experts.
%% =============================================================

relativeDistance_ind = zeros(n,nExperts);
supportPres_ind      = zeros(n,nExperts);
corePres_ind         = zeros(n,nExperts);
areaPres_ind         = zeros(n,nExperts);

supportFull_ind = zeros(n,nExperts);
supportExpr_ind = zeros(n,nExperts);
coreFull_ind    = zeros(n,nExperts);
coreExpr_ind    = zeros(n,nExperts);
areaFull_ind    = zeros(n,nExperts);
areaExpr_ind    = zeros(n,nExperts);

for s = 1:nExperts

    for k = 1:n

        tB = squeeze(Wf_full_ind(k,:,s));
        tE = squeeze(Wf_expr_ind(k,:,s));

        % Relative Euclidean distance (%)
        relativeDistance_ind(k,s) = ...
            100 * norm(tB-tE,2) / max(norm(tB,2),eps);

        % Individual fuzzy geometry
        supportFull_ind(k,s) = tB(4)-tB(1);
        supportExpr_ind(k,s) = tE(4)-tE(1);

        coreFull_ind(k,s) = tB(3)-tB(2);
        coreExpr_ind(k,s) = tE(3)-tE(2);

        areaFull_ind(k,s) = ...
            (supportFull_ind(k,s)+coreFull_ind(k,s))/2;

        areaExpr_ind(k,s) = ...
            (supportExpr_ind(k,s)+coreExpr_ind(k,s))/2;

     supportPres_ind(k,s) = ...
    100 * min(supportFull_ind(k,s),supportExpr_ind(k,s)) / ...
    max([supportFull_ind(k,s),supportExpr_ind(k,s),eps]);

corePres_ind(k,s) = ...
    100 * min(coreFull_ind(k,s),coreExpr_ind(k,s)) / ...
    max([coreFull_ind(k,s),coreExpr_ind(k,s),eps]);

areaPres_ind(k,s) = ...
    100 * min(areaFull_ind(k,s),areaExpr_ind(k,s)) / ...
    max([areaFull_ind(k,s),areaExpr_ind(k,s),eps]);

    end
end



meanRelativeDistance = mean(relativeDistance_ind,2);
sdRelativeDistance   = std(relativeDistance_ind,0,2);
maxRelativeDistance  = max(relativeDistance_ind,[],2);

meanSupportPres = mean(supportPres_ind,2);
meanCorePres    = mean(corePres_ind,2);
meanAreaPres    = mean(areaPres_ind,2);

Table5 = table( ...
    criteria, ...
    meanRelativeDistance, ...
    sdRelativeDistance, ...
    maxRelativeDistance, ...
    meanSupportPres, ...
    meanCorePres, ...
    meanAreaPres, ...
    'VariableNames', { ...
        'Criterion', ...
        'MeanRelativeDistance_Percent', ...
        'SD_Percent', ...
        'MaximumRelativeDistance_Percent', ...
        'SupportPreservation_Percent', ...
        'CorePreservation_Percent', ...
        'AreaPreservation_Percent'});

fprintf('\n============================================================\n');
fprintf('TABLE 5 - INDIVIDUAL-LEVEL PRESERVATION\n');
fprintf('============================================================\n');
disp(Table5);


%% =============================================================
% 12. MOST DIVERGENT EXPERT
%
% The most divergent expert is identified by the largest mean
% relative Euclidean distance across the five criteria.
%% =============================================================

meanRelativeDistanceExpert = mean(relativeDistance_ind,1);

[worstMeanDistance,worstExpert] = ...
    max(meanRelativeDistanceExpert);

worstExpertName = string(sheets{worstExpert});

fprintf('\n============================================================\n');
fprintf('MOST DIVERGENT EXPERT\n');
fprintf('============================================================\n');
fprintf('Expert / sheet: %s\n',worstExpertName);
fprintf('Mean relative Euclidean distance = %.2f %%\n',worstMeanDistance);

MostDivergent = table( ...
    criteria, ...
    relativeDistance_ind(:,worstExpert), ...
    supportPres_ind(:,worstExpert), ...
    corePres_ind(:,worstExpert), ...
    areaPres_ind(:,worstExpert), ...
    'VariableNames', { ...
        'Criterion', ...
        'RelativeDistance_Percent', ...
        'SupportPreservation_Percent', ...
        'CorePreservation_Percent', ...
        'AreaPreservation_Percent'});

disp(MostDivergent);

% Graphical comparison for the most divergent expert
figure('Color','w','Position',[80 80 1250 720], ...
    'Name','Most_Divergent_Expert_Fuzzy_Weights');

for k = 1:n

    subplot(2,3,k);

    tB = squeeze(Wf_full_ind(k,:,worstExpert));
    tE = squeeze(Wf_expr_ind(k,:,worstExpert));

    [xB,yB] = trapezoidXY(tB);
    [xE,yE] = trapezoidXY(tE);

    hold on;

    fill(xB,yB,[0.30 0.40 1.00], ...
        'FaceAlpha',0.35, ...
        'EdgeColor',[0.20 0.30 0.90], ...
        'LineWidth',1.1);

    fill(xE,yE,[1.00 0.35 0.35], ...
        'FaceAlpha',0.35, ...
        'EdgeColor',[0.90 0.20 0.20], ...
        'LineWidth',1.1);

    title(criteria{k},'FontWeight','bold');
    ylim([0 1.08]);
    ylabel('\mu(x)');
    grid on;
    box on;

    xmin = min([tB(1),tE(1)]);
    xmax = max([tB(4),tE(4)]);
    margem = max(0.02*(xmax-xmin),1e-4);
    xlim([xmin-margem xmax+margem]);

    if k == n
        legend({'Buckley','Express'},'Location','best');
    end

    hold off;
end

sgtitle(sprintf('Most Divergent Expert: %s (Mean Relative Distance = %.1f%%)', ...
    worstExpertName,worstMeanDistance), ...
    'FontWeight','bold');

exportgraphics(gcf,'Most_Divergent_Expert_Fuzzy_Weights.png','Resolution',300);
exportgraphics(gcf,'Most_Divergent_Expert_Fuzzy_Weights.pdf','ContentType','vector');


%% =============================================================
% 13. HEATMAP - TRAPEZOIDAL AREA PRESERVATION FOR ALL EXPERTS
%% =============================================================

figure('Color','w','Position',[80 80 1350 520], ...
    'Name','Area_Preservation_All_Experts');

imagesc(areaPres_ind);

colormap(parula);
caxis([0 100]);

cb = colorbar;
cb.Label.String = 'Trapezoidal area preservation (%)';

yticks(1:n);
yticklabels(criteria);

xticks(1:nExperts);
xticklabels(sheets);
xtickangle(45);

xlabel('Expert / worksheet');
ylabel('Criterion');

title('Trapezoidal Area Preservation (%)', ...
    'FontWeight','bold');

set(gca,'TickLength',[0 0]);
box on;

% Numerical labels
for k = 1:n
    for s = 1:nExperts

        value = areaPres_ind(k,s);

        % Better contrast with parula
        if value < 45
            txtColor = 'w';
        else
            txtColor = 'k';
        end

        text(s,k,sprintf('%.0f',value), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','middle', ...
            'FontSize',8, ...
            'FontWeight','bold', ...
            'Color',txtColor);
    end
end

exportgraphics(gcf,'Heatmap_Area_Preservation_All_Experts.png','Resolution',300);
exportgraphics(gcf,'Heatmap_Area_Preservation_All_Experts.pdf','ContentType','vector');


%% =============================================================
% 14. OPTIONAL HEATMAPS - SUPPORT AND CORE PRESERVATION
%% =============================================================

figure('Color','w','Position',[80 80 1350 520], ...
    'Name','Support_Preservation_All_Experts');

imagesc(supportPres_ind);
colormap(parula);
caxis([0 100]);
cb = colorbar;
cb.Label.String = 'Support width preservation (%)';
yticks(1:n);
yticklabels(criteria);
xticks(1:nExperts);
xticklabels(sheets);
xtickangle(45);
xlabel('Expert / worksheet');
ylabel('Criterion');
title('Support Width Preservation (%)','FontWeight','bold');
set(gca,'TickLength',[0 0]);
box on;

exportgraphics(gcf,'Heatmap_Support_Preservation_All_Experts.png','Resolution',300);
exportgraphics(gcf,'Heatmap_Support_Preservation_All_Experts.pdf','ContentType','vector');


figure('Color','w','Position',[80 80 1350 520], ...
    'Name','Core_Preservation_All_Experts');

imagesc(corePres_ind);
colormap(parula);
caxis([0 100]);
cb = colorbar;
cb.Label.String = 'Core width preservation (%)';
yticks(1:n);
yticklabels(criteria);
xticks(1:nExperts);
xticklabels(sheets);
xtickangle(45);
xlabel('Expert / worksheet');
ylabel('Criterion');
title('Core Width Preservation (%)','FontWeight','bold');
set(gca,'TickLength',[0 0]);
box on;

exportgraphics(gcf,'Heatmap_Core_Preservation_All_Experts.png','Resolution',300);
exportgraphics(gcf,'Heatmap_Core_Preservation_All_Experts.pdf','ContentType','vector');



%% =============================================================
% 15. EXPORT RESULTS
%% =============================================================

outputFile = ...
    'FAHP_Express_Group_Comparison.xlsx';

if isfile(outputFile)
    delete(outputFile);
end

writetable(Table3, ...
    outputFile, ...
    'Sheet','Table3_Weights');

writetable(Table4, ...
    outputFile, ...
    'Sheet','Table4_FuzzyMetrics');

writetable(GroupFuzzy, ...
    outputFile, ...
    'Sheet','Group_Fuzzy');

writetable(Individual, ...
    outputFile, ...
    'Sheet','Individual');


writetable(Table5, ...
    outputFile, ...
    'Sheet','Table5_IndividualPres');

writetable(MostDivergent, ...
    outputFile, ...
    'Sheet','Most_Divergent_Expert');

% Full expert x criterion matrices for audit/heatmap reproduction
AreaPreservationAll = array2table( ...
    areaPres_ind', ...
    'VariableNames', matlab.lang.makeValidName(criteria));

AreaPreservationAll = addvars( ...
    AreaPreservationAll, ...
    string(sheets(:)), ...
    'Before',1, ...
    'NewVariableNames','Expert');

writetable(AreaPreservationAll, ...
    outputFile, ...
    'Sheet','Area_Preservation_All');

RelativeDistanceAll = array2table( ...
    relativeDistance_ind', ...
    'VariableNames', matlab.lang.makeValidName(criteria));

RelativeDistanceAll = addvars( ...
    RelativeDistanceAll, ...
    string(sheets(:)), ...
    'Before',1, ...
    'NewVariableNames','Expert');

writetable(RelativeDistanceAll, ...
    outputFile, ...
    'Sheet','Relative_Distance_All');

% Reference judgments used by Express
ReferenceTable = array2table( ...
    reference_rows, ...
    'VariableNames', matlab.lang.makeValidName(criteria));

ReferenceTable = addvars( ...
    ReferenceTable, ...
    sheetColumn, ...
    'Before',1, ...
    'NewVariableNames','Sheet');

writetable(ReferenceTable, ...
    outputFile, ...
    'Sheet','Express_References');

fprintf('\n============================================================\n');
fprintf('RESULTS EXPORTED\n');
fprintf('============================================================\n');
fprintf('%s\n',outputFile);

%% =============================================================
% LOCAL FUNCTIONS
%% =============================================================

function value = parseSaatyCell(x)

    % Numeric spreadsheet value
    if isnumeric(x)

        if isempty(x) || isnan(x)
            error('Empty or NaN pairwise judgment.');
        end

        value = double(x);
        return;

    end

    if ismissing(x)
        error('Missing pairwise judgment.');
    end

    s = strtrim(string(x));

    if strlength(s) == 0
        error('Empty pairwise judgment.');
    end

    % Remove leading "=" if the upper-triangle cell contains
    % a simple Excel formula such as "=1/3".
    if startsWith(s,"=")
        s = extractAfter(s,1);
    end

    % Simple fraction such as 1/3, 1/5, ...
    if contains(s,"/")

        parts = split(s,"/");

        if numel(parts) ~= 2
            error('Unsupported Saaty expression: %s',s);
        end

        numerator = str2double(parts(1));
        denominator = str2double(parts(2));

        if isnan(numerator) || isnan(denominator) || denominator == 0
            error('Unsupported Saaty fraction: %s',s);
        end

        value = numerator / denominator;
        return;

    end

    % Plain numeric string
    value = str2double(s);

    if isnan(value)
        error('Could not parse pairwise judgment: %s',s);
    end

end


function A = reconstructExpress(referenceRow)

    referenceRow = double(referenceRow(:)');

    n = numel(referenceRow);

    A = ones(n);

    for i = 1:n
        for j = 1:n

            A(i,j) = ...
                referenceRow(j) / referenceRow(i);

        end
    end

    A(1:n+1:end) = 1;

end


function F = fuzzifyMatrixReciprocal(A)

    n = size(A,1);

    F = zeros(n,n,4);

    % Diagonal
    for i = 1:n
        F(i,i,:) = [1 1 1 1];
    end

    % Fuzzify only one side and derive the reciprocal side
    % by exact fuzzy inversion.
    for i = 1:n

        for j = i+1:n

            x = A(i,j);

            if x >= 1

                tij = crispToFuzzyTrap(x);

                tji = [ ...
                    1/tij(4), ...
                    1/tij(3), ...
                    1/tij(2), ...
                    1/tij(1)];

            else

                % If the upper-triangle judgment itself is < 1,
                % fuzzify its direct reciprocal first.
                tji = crispToFuzzyTrap(1/x);

                tij = [ ...
                    1/tji(4), ...
                    1/tji(3), ...
                    1/tji(2), ...
                    1/tji(1)];

            end

            F(i,j,:) = tij;
            F(j,i,:) = tji;

        end
    end

end


function trap = crispToFuzzyTrap(x)

    % Adopted trapezoidal linguistic scale
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

    if ~isscalar(x) || ~isfinite(x) || x <= 0
        error('Comparison value must be positive and finite.');
    end

    if x < 1 - 1e-12
        error(['crispToFuzzyTrap expects a direct value >= 1. ' ...
               'Reciprocal values must be generated by exact fuzzy inversion.']);
    end

    if x > 9 + 1e-12
        error('Comparison value exceeds Saaty scale: %.6f',x);
    end

    % Identity
    if abs(x-1) < 1e-12
        trap = [1 1 1 1];
        return;
    end

    % Exact discrete scale point
    if abs(x-round(x)) < 1e-12

        k = round(x);
        trap = scale(k,2:5);
        return;

    end

    % Linear interpolation for intermediate x > 1
    lower = floor(x);
    upper = ceil(x);

    lambda = ...
        (x-lower)/(upper-lower);

    trap = ...
        (1-lambda)*scale(lower,2:5) + ...
        lambda*scale(upper,2:5);

end


function [Wcrisp,Wfuzzy] = buckleyWeights(F)

    n = size(F,1);

    R = zeros(n,4);

    % Fuzzy geometric means
    for i = 1:n

        product = [1 1 1 1];

        for j = 1:n

            t = squeeze(F(i,j,:))';

            product = ...
                product .* t;

        end

        R(i,:) = ...
            product.^(1/n);

    end

    % Fuzzy normalization
    sumR = sum(R,1);

    invSumR = [ ...
        1/sumR(4), ...
        1/sumR(3), ...
        1/sumR(2), ...
        1/sumR(1)];

    Wfuzzy = ...
        R .* invSumR;

    % Vertex defuzzification and crisp normalization
    Wcrisp = ...
        mean(Wfuzzy,2);

    Wcrisp = ...
        Wcrisp / sum(Wcrisp);

end


function CR = calculateCR(A)

    n = size(A,1);

    eigenvalues = eig(A);

    lambdaMax = ...
        max(real(eigenvalues));

    CI = ...
        (lambdaMax-n)/(n-1);

    RIvalues = [ ...
        0.00, ...
        0.00, ...
        0.58, ...
        0.90, ...
        1.12, ...
        1.24, ...
        1.32, ...
        1.41, ...
        1.45, ...
        1.49, ...
        1.51, ...
        1.48, ...
        1.56, ...
        1.57, ...
        1.59];

    if n <= 2

        CR = 0;

    elseif n <= numel(RIvalues)

        CR = ...
            CI / RIvalues(n);

    else

        % Common approximation for larger n
        RI = 1.98*(n-2)/n;
        CR = CI/RI;

    end

end


function assertFuzzyReciprocity(F,tol,label)

    n = size(F,1);

    for i = 1:n

        for j = i+1:n

            tij = squeeze(F(i,j,:))';
            tji = squeeze(F(j,i,:))';

            expected = [ ...
                1/tij(4), ...
                1/tij(3), ...
                1/tij(2), ...
                1/tij(1)];

            if max(abs(tji-expected)) > tol

                error( ...
                    'Fuzzy reciprocity failure in %s at (%d,%d).', ...
                    label,i,j);

            end

        end
    end

end



function [x,y] = trapezoidXY(t)

    % Coordinates for plotting trapezoidal fuzzy number [l m n u]
    l = t(1);
    m = t(2);
    n = t(3);
    u = t(4);

    x = [l m n u];
    y = [0 1 1 0];

end


function ranks = getRanks(weights)

    weights = weights(:);

    [~,order] = ...
        sort(weights,'descend');

    ranks = zeros(size(weights));

    ranks(order) = ...
        (1:numel(weights))';

end

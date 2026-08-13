%% MONTE CARLO VALIDATION - BALANCED VERSION
% Buckley FAHP vs Reduced-Comparison FAHP-Express
%
% Balanced factorial design:
%   n = [5 7 10 15]
%   CR bands = [0,.05), [.05,.10), [.10,.20), [.20,.30)
%   5000 ACCEPTED matrices per (n x CR band) cell
%
% Total accepted simulations = 4 * 4 * 5000 = 80,000
%
% Figures generated:
%   Fig. 1 - CR x MAE
%   Fig. 2 - CR x fuzzy-area preservation
%   Fig. 3 - Normalized MAE x number of criteria
%   Fig. 4 - Spearman x CR
%
% No additional toolbox is required except that BOXPLOT may require
% Statistics and Machine Learning Toolbox in some MATLAB versions.
% If unavailable, replace the boxplot section with grouped scatter/means.

clear;
clc;
close all;

rng(2026); % Reproducibility

%% =====================================================================
% CONFIGURATION
% ======================================================================

nCriteriaVec = [5 7 10 15];

% Number of ACCEPTED matrices in each n x CR-band cell
NperCell = 5000;

% CR bands: [lower, upper)
CRbands = [...
    0.00 0.05;
    0.05 0.10;
    0.10 0.20;
    0.20 0.30];

CRlabels = {...
    'CR < 0.05';
    '0.05 <= CR < 0.10';
    '0.10 <= CR < 0.20';
    '0.20 <= CR < 0.30'};

% Sigma proposal ranges used only to make rejection sampling efficient.
% Final acceptance is determined EXCLUSIVELY by the calculated CR.
sigmaRanges = [...
    0.05 0.45;
    0.35 0.70;
    0.55 0.90;
    0.75 1.10];

saatyMax = 9;

% Safety limit for rejection sampling
maxAttemptsPerCell = 500000;

%% =====================================================================
% STORAGE
% ======================================================================

% Columns:
% 1 Simulation
% 2 Ncriteria
% 3 CRband
% 4 Sigma
% 5 CR
% 6 MAE
% 7 NMAE_percent
% 8 RMSE
% 9 MaxAbsError
% 10 Spearman
% 11 SameTop1
% 12 SameRanking
% 13 FuzzyDistance
% 14 SupportPreservation
% 15 CorePreservation
% 16 AreaPreservation

nTotalExpected = length(nCriteriaVec) * size(CRbands,1) * NperCell;
Results = zeros(nTotalExpected,16);

simulationID = 0;
row = 0;

%% =====================================================================
% MAIN BALANCED MONTE CARLO LOOP
% ======================================================================

for nn = 1:length(nCriteriaVec)

    n = nCriteriaVec(nn);

    fprintf('\n====================================================\n');
    fprintf('n = %d criteria\n', n);
    fprintf('====================================================\n');

    for b = 1:size(CRbands,1)

        crLow  = CRbands(b,1);
        crHigh = CRbands(b,2);

        accepted = 0;
        attempts = 0;

        fprintf('Target band: %s\n', CRlabels{b});

        while accepted < NperCell

            attempts = attempts + 1;

            if attempts > maxAttemptsPerCell
                error(['Maximum number of attempts reached for n = %d, ' ...
                       'CR band = %s. Adjust sigmaRanges.'], ...
                       n, CRlabels{b});
            end

            %% ---------------------------------------------------------
            % 1. GENERATE LATENT "TRUE" PRIORITIES
            % ----------------------------------------------------------

            latentScore = log(saatyMax) * rand(n,1);

            trueWeight = exp(latentScore);
            trueWeight = trueWeight / sum(trueWeight);

            %% ---------------------------------------------------------
            % 2. PERFECTLY CONSISTENT AHP MATRIX
            % ----------------------------------------------------------

            Atrue = ones(n);

            for i = 1:n
                for j = i+1:n

                    value = trueWeight(i) / trueWeight(j);

                    Atrue(i,j) = value;
                    Atrue(j,i) = 1/value;

                end
            end

            %% ---------------------------------------------------------
            % 3. ADD MULTIPLICATIVE JUDGMENT NOISE
            % ----------------------------------------------------------

            sigma = sigmaRanges(b,1) + ...
                (sigmaRanges(b,2)-sigmaRanges(b,1))*rand;

            A = ones(n);

            for i = 1:n
                for j = i+1:n

                    epsilon = sigma * randn;

                    value = Atrue(i,j) * exp(epsilon);

                    % Keep elicited judgments inside Saaty's scale
                    value = min(max(value,1/saatyMax),saatyMax);

                    A(i,j) = value;
                    A(j,i) = 1/value;

                end
            end

            %% ---------------------------------------------------------
            % 4. CALCULATE CR AND APPLY BALANCING FILTER
            % ----------------------------------------------------------

            CR = calculateCR(A);

            % Reject matrices outside the target CR band
            if ~(CR >= crLow && CR < crHigh)
                continue;
            end

            accepted = accepted + 1;
            simulationID = simulationID + 1;
            row = row + 1;

            %% ---------------------------------------------------------
            % 5. CONVENTIONAL BUCKLEY FAHP
            % ----------------------------------------------------------

            fuzzyFull = fuzzifyMatrix(A);

            [weightsFull, fuzzyWeightsFull] = ...
                buckleyWeights(fuzzyFull);

            %% ---------------------------------------------------------
            % 6. CHOOSE REFERENCE CRITERION
            % ----------------------------------------------------------

            % Most important latent criterion, following the strategy
            % adopted in the paper.
            [~, ref] = max(trueWeight);

            %% ---------------------------------------------------------
            % 7. AHP-EXPRESS RECONSTRUCTION
            % ----------------------------------------------------------

            Aexpress = ones(n);

            for i = 1:n
                for j = 1:n

                    % a_ij = a_ref,j / a_ref,i
                    Aexpress(i,j) = A(ref,j) / A(ref,i);

                end
            end

            % Preserve reciprocal structure and Saaty bounds.
            % NOTE: clipping can slightly alter perfect reconstructed
            % transitivity when a ratio exceeds the scale limits.
            for i = 1:n

                for j = i+1:n

                    value = Aexpress(i,j);
                    value = min(max(value,1/saatyMax),saatyMax);

                    Aexpress(i,j) = value;
                    Aexpress(j,i) = 1/value;

                end

                Aexpress(i,i) = 1;

            end

            %% ---------------------------------------------------------
            % 8. BUCKLEY FAHP-EXPRESS
            % ----------------------------------------------------------

            fuzzyExpress = fuzzifyMatrix(Aexpress);

            [weightsExpress, fuzzyWeightsExpress] = ...
                buckleyWeights(fuzzyExpress);

            %% ---------------------------------------------------------
            % 9. WEIGHT ERRORS
            % ----------------------------------------------------------

            absError = abs(weightsFull - weightsExpress);

            MAE = mean(absError);

            RMSE = sqrt(mean((weightsFull - weightsExpress).^2));

            MaxAbsError = max(absError);

            % Normalized MAE:
            % mean(weightsFull) = 1/n because weights sum to 1.
            % Expressed as % of the mean criterion weight.
            NMAE_percent = 100 * MAE / mean(weightsFull);

            %% ---------------------------------------------------------
            % 10. RANKING COMPARISON
            % ----------------------------------------------------------

            rankFull = getRanks(weightsFull);
            rankExpress = getRanks(weightsExpress);

            Spearman = corrSimple(rankFull,rankExpress);

            [~,topFull] = max(weightsFull);
            [~,topExpress] = max(weightsExpress);

            SameTop1 = double(topFull == topExpress);
            SameRanking = double(all(rankFull == rankExpress));

            %% ---------------------------------------------------------
            % 11. FUZZY-NUMBER COMPARISON
            % ----------------------------------------------------------

            distances = zeros(n,1);

            supportPres = zeros(n,1);
            corePres    = zeros(n,1);
            areaPres    = zeros(n,1);

            for i = 1:n

                B = fuzzyWeightsFull(i,:);
                E = fuzzyWeightsExpress(i,:);

                % Euclidean distance
                distances(i) = norm(B-E);

                % Support
                SB = B(4)-B(1);
                SE = E(4)-E(1);

                supportPres(i) = ...
                    100*(1 - abs(SB-SE)/max(SB,eps));

                % Core
                CB = B(3)-B(2);
                CE = E(3)-E(2);

                corePres(i) = ...
                    100*(1 - abs(CB-CE)/max(CB,eps));

                % Trapezoidal area
                AB = (SB+CB)/2;
                AE = (SE+CE)/2;

                areaPres(i) = ...
                    100*(1 - abs(AB-AE)/max(AB,eps));

            end

            % Preservation is bounded below at zero
            supportPres = max(supportPres,0);
            corePres    = max(corePres,0);
            areaPres    = max(areaPres,0);

            meanFuzzyDistance = mean(distances);
            meanSupportPres   = mean(supportPres);
            meanCorePres      = mean(corePres);
            meanAreaPres      = mean(areaPres);

            %% ---------------------------------------------------------
            % 12. STORE RESULTS
            % ----------------------------------------------------------

            Results(row,:) = [...
                simulationID,...
                n,...
                b,...
                sigma,...
                CR,...
                MAE,...
                NMAE_percent,...
                RMSE,...
                MaxAbsError,...
                Spearman,...
                SameTop1,...
                SameRanking,...
                meanFuzzyDistance,...
                meanSupportPres,...
                meanCorePres,...
                meanAreaPres];

            if mod(accepted,1000) == 0
                fprintf('  Accepted %d / %d (attempts = %d)\n', ...
                    accepted,NperCell,attempts);
            end

        end

        fprintf('Completed %s: %d accepted from %d attempts.\n', ...
            CRlabels{b},accepted,attempts);

    end
end

%% =====================================================================
% RESULTS TABLE
% ======================================================================

Results = Results(1:row,:);

T = array2table(Results, ...
    'VariableNames', { ...
        'Simulation', ...
        'Ncriteria', ...
        'CRbandID', ...
        'Sigma', ...
        'CR', ...
        'MAE', ...
        'NMAE_Percent', ...
        'RMSE', ...
        'MaxAbsError', ...
        'Spearman', ...
        'SameTop1', ...
        'SameRanking', ...
        'FuzzyDistance', ...
        'SupportPreservation', ...
        'CorePreservation', ...
        'AreaPreservation'});

bandText = strings(height(T),1);

for i = 1:height(T)
    bandText(i) = string(CRlabels{T.CRbandID(i)});
end

T.CRgroup = categorical(bandText, string(CRlabels), 'Ordinal', true);

writetable(T,'MonteCarlo_FAHP_Express_Balanced.csv');

%% =====================================================================
% SUMMARY BY NUMBER OF CRITERIA
% Because every n has the SAME number of observations in every CR band,
% comparisons across n are balanced for inconsistency.
% ======================================================================

SummaryN = zeros(length(nCriteriaVec),10);

for nn = 1:length(nCriteriaVec)

    n = nCriteriaVec(nn);
    idx = T.Ncriteria == n;

    SummaryN(nn,:) = [...
        n,...
        mean(T.CR(idx)),...
        mean(T.MAE(idx)),...
        mean(T.NMAE_Percent(idx)),...
        mean(T.RMSE(idx)),...
        mean(T.Spearman(idx)),...
        100*mean(T.SameTop1(idx)),...
        mean(T.FuzzyDistance(idx)),...
        mean(T.AreaPreservation(idx)),...
        sum(idx)];

end

SummaryNTable = array2table(SummaryN, ...
    'VariableNames', { ...
        'Ncriteria', ...
        'MeanCR', ...
        'MAE', ...
        'NMAE_Percent', ...
        'RMSE', ...
        'MeanSpearman', ...
        'SameTop1_Percent', ...
        'FuzzyDistance', ...
        'AreaPreservation', ...
        'Nsim'});

disp(' ');
disp('========== BALANCED SUMMARY BY NUMBER OF CRITERIA ==========');
disp(SummaryNTable);

writetable(SummaryNTable, ...
    'MonteCarlo_FAHP_Express_Balanced_ByN.csv');

%% =====================================================================
% SUMMARY BY CR BAND
% ======================================================================

SummaryCR = zeros(size(CRbands,1),9);

for b = 1:size(CRbands,1)

    idx = T.CRbandID == b;

    SummaryCR(b,:) = [...
        b,...
        sum(idx),...
        mean(T.CR(idx)),...
        mean(T.MAE(idx)),...
        mean(T.NMAE_Percent(idx)),...
        mean(T.Spearman(idx)),...
        100*mean(T.SameTop1(idx)),...
        mean(T.FuzzyDistance(idx)),...
        mean(T.AreaPreservation(idx))];

end

SummaryCRTable = array2table(SummaryCR, ...
    'VariableNames', { ...
        'CRbandID', ...
        'Nsim', ...
        'MeanCR', ...
        'MAE', ...
        'NMAE_Percent', ...
        'Spearman', ...
        'SameTop1_Percent', ...
        'FuzzyDistance', ...
        'AreaPreservation'});

SummaryCRTable.CRgroup = string(CRlabels);

SummaryCRTable = movevars(SummaryCRTable, ...
    'CRgroup','Before',1);

disp(' ');
disp('========== BALANCED RESULTS BY CR BAND ==========');
disp(SummaryCRTable);

writetable(SummaryCRTable, ...
    'MonteCarlo_FAHP_Express_Balanced_ByCR.csv');

%% =====================================================================
% FIGURE 1 - CR x MAE
% ======================================================================

figure;

scatter(T.CR,T.MAE,8,'filled');

hold on;

p = polyfit(T.CR,T.MAE,1);
xFit = linspace(min(T.CR),max(T.CR),200);
yFit = polyval(p,xFit);

plot(xFit,yFit,'LineWidth',2);

hold off;

xlabel('Consistency Ratio of conventional matrix');
ylabel('Mean Absolute Error of weights');
title('Effect of Preference Inconsistency on FAHP-Express Approximation');
grid on;

%% =====================================================================
% FIGURE 2 - CR x FUZZY-AREA PRESERVATION
% ======================================================================

figure;

scatter(T.CR,T.AreaPreservation,8,'filled');

hold on;

p = polyfit(T.CR,T.AreaPreservation,1);
xFit = linspace(min(T.CR),max(T.CR),200);
yFit = polyval(p,xFit);

plot(xFit,yFit,'LineWidth',2);

hold off;

xlabel('Consistency Ratio of conventional matrix');
ylabel('Trapezoidal Area Preservation (%)');
title('Fuzzy Uncertainty Preservation vs Preference Inconsistency');
grid on;

%% =====================================================================
% FIGURE 3 - NORMALIZED MAE x NUMBER OF CRITERIA
%
% NMAE = MAE / mean conventional weight
%      = MAE / (1/n)
%
% This avoids the artificial reduction in raw MAE caused by the fact
% that individual normalized weights become smaller as n increases.
% ======================================================================

figure;

boxplot(T.NMAE_Percent,T.Ncriteria);

xlabel('Number of criteria');
ylabel('Normalized MAE (% of mean criterion weight)');
title('Normalized Approximation Error vs Number of Criteria');
grid on;

%% =====================================================================
% FIGURE 4 - SPEARMAN x CR
% ======================================================================

figure;

scatter(T.CR,T.Spearman,8,'filled');

hold on;

p = polyfit(T.CR,T.Spearman,1);
xFit = linspace(min(T.CR),max(T.CR),200);
yFit = polyval(p,xFit);

plot(xFit,yFit,'LineWidth',2);

hold off;

xlabel('Consistency Ratio of conventional matrix');
ylabel('Spearman rank correlation');
title('Ranking Preservation vs Preference Inconsistency');
grid on;

%% =====================================================================
% FUNCTIONS
% ======================================================================

function CR = calculateCR(A)

    n = size(A,1);

    eigenValues = eig(A);
    lambdaMax = max(real(eigenValues));

    CI = (lambdaMax-n)/(n-1);

    RIvalues = [...
        0,...
        0,...
        0.58,...
        0.90,...
        1.12,...
        1.24,...
        1.32,...
        1.41,...
        1.45,...
        1.49,...
        1.51,...
        1.48,...
        1.56,...
        1.57,...
        1.59];

    if n <= 2

        CR = 0;

    elseif n <= length(RIvalues)

        RI = RIvalues(n);
        CR = CI/RI;

    else

        RI = 1.98*(n-2)/n;
        CR = CI/RI;

    end

end

%% =====================================================================

function F = fuzzifyMatrix(A)

    n = size(A,1);
    F = zeros(n,n,4);

    for i = 1:n
        for j = 1:n

            F(i,j,:) = fuzzifyValue(A(i,j));

        end
    end

end

%% =====================================================================

function fuzzy = fuzzifyValue(x)

    scale = [...
        1 1.0 1.0 1.0 1.0;
        2 1.0 1.5 2.5 3.0;
        3 2.0 2.5 3.5 4.0;
        4 3.0 3.5 4.5 5.0;
        5 4.0 4.5 5.5 6.0;
        6 5.0 5.5 6.5 7.0;
        7 6.0 6.5 7.5 8.0;
        8 7.0 7.5 8.5 9.0;
        9 8.0 8.5 9.0 9.0];

    if ~isscalar(x) || ~isfinite(x) || x <= 0
        error('Comparison value must be a finite positive scalar.');
    end

    %% ---------------------------------------------------------
    % IDENTITY
    %% ---------------------------------------------------------

    if abs(x - 1) < 1e-12

        fuzzy = [1 1 1 1];
        return;

    end

    %% ---------------------------------------------------------
    % RECIPROCAL COMPARISONS
    %
    % Do NOT interpolate independently in the reciprocal domain.
    % First obtain the fuzzy representation of 1/x and then
    % compute its exact fuzzy reciprocal:
    %
    % (l,m,n,u)^(-1) = (1/u,1/n,1/m,1/l)
    %% ---------------------------------------------------------

    if x < 1

        % Preserve Saaty bounds
        x = max(x,1/9);

        directFuzzy = fuzzifyValue(1/x);

        fuzzy = [...
            1/directFuzzy(4), ...
            1/directFuzzy(3), ...
            1/directFuzzy(2), ...
            1/directFuzzy(1)];

        return;

    end

    %% ---------------------------------------------------------
    % DIRECT COMPARISONS x >= 1
    %% ---------------------------------------------------------

    x = min(x,9);

    % Exact value of adopted scale
    if abs(x-round(x)) < 1e-12

        k = round(x);
        fuzzy = scale(k,2:5);
        return;

    end

    %% ---------------------------------------------------------
    % LINEAR INTERPOLATION FOR INTERMEDIATE VALUES > 1
    %% ---------------------------------------------------------

    lower = floor(x);
    upper = ceil(x);

    lambda = ...
        (x-lower)/(upper-lower);

    fuzzy = ...
        (1-lambda)*scale(lower,2:5) + ...
        lambda*scale(upper,2:5);

end
%% =====================================================================

function [Wcrisp,Wfuzzy] = buckleyWeights(F)

    n = size(F,1);

    R = zeros(n,4);

    for i = 1:n

        product = ones(1,4);

        for j = 1:n

            value = squeeze(F(i,j,:))';
            product = product .* value;

        end

        R(i,:) = product.^(1/n);

    end

    sumR = sum(R,1);

    invSum = [...
        1/sumR(4),...
        1/sumR(3),...
        1/sumR(2),...
        1/sumR(1)];

    Wfuzzy = zeros(n,4);

    for i = 1:n
        Wfuzzy(i,:) = R(i,:) .* invSum;
    end

    Wcrisp = mean(Wfuzzy,2);
    Wcrisp = Wcrisp / sum(Wcrisp);

end

%% =====================================================================

function ranks = getRanks(weights)

    n = length(weights);

    [~,order] = sort(weights,'descend');

    ranks = zeros(n,1);

    for i = 1:n
        ranks(order(i)) = i;
    end

end

%% =====================================================================

function r = corrSimple(x,y)

    x = x(:);
    y = y(:);

    x = x-mean(x);
    y = y-mean(y);

    denominator = sqrt(sum(x.^2)*sum(y.^2));

    if denominator == 0
        r = 1;
    else
        r = sum(x.*y)/denominator;
    end

end

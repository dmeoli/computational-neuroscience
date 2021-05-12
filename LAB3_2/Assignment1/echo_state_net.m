%%%%%%%%%%%%%%% Echo State Network %%%%%%%%%%%%%%%
clear variables;

load('NARMA10timeseries.mat');  % import data
input = cell2mat(NARMA10timeseries.input);
target = cell2mat(NARMA10timeseries.target);

steps = 5000;
val_steps = 4000;

% design set
X_design = input(1:steps);
Y_design = target(1:steps);
% test set
X_test = input(steps+1:end);
Y_test = target(steps+1:end);
% training set
X_train = X_design(1:val_steps);
Y_train = Y_design(1:val_steps);
% validation set
X_val = X_design(val_steps+1:end);
Y_val = Y_design(val_steps+1:end);

% parameters for grid search
input_scaling = [0.5 1 2];
Nrs = [5 10 25 50 100];  % reservoir dimension (number of recurrent units)
rho_values = [0.1 0.5 0.9 1.2 3];  % spectral radius
lambdas = [0.0001 0.001 0.01 0.1];  % readout regularization for ridge regression
% connectivity = [0.9 0.7 0.5];  % percentage of connectivity among reservoir units

[I, NR, R, L] = ndgrid(input_scaling,Nrs,rho_values,lambdas);
grid = [I(:) NR(:) R(:) L(:)];
% [I, NR, R, L, C] = ndgrid(input_scaling,Nrs,rho_values,lambdas,connectivity);
% grid = [I(:) NR(:) R(:) L(:) C(:)];

ERS = [];
min_err_val = inf;

for g = 1:size(grid,1)
    
    omega_in = grid(g,1);
    Nr = grid(g,2);
    rho = grid(g,3);
    l = grid(g,4);
%     c = grid(g,5);
    
    guesses = 10;  % network guesses for each reservoir hyper-parametrization
    Nu = size(X_train,1);
    trainingSteps = size(X_train,2);
    validationSteps = size(X_val,2);
    E_trs = [];
    E_vals = [];
    
    fprintf('Input scaling: %.2f - Reservoir dimension: %d Spectral radius: %.2f - Lambda: %.4f\n', omega_in, Nr, rho, l);
%     fprintf('Input scaling: %.2f - Reservoir dimension: %d Spectral radius: %.2f - Lambda: %.4f - Connectivity percentage: %.2f\n', omega_in, Nr, rho, l, c);
    
    for n = 1:guesses        
        % initialize the input-to-reservoir matrix
        U = 2*rand(Nr,Nu)-1;
        U = omega_in * U;
        % initialize the inter-reservoir weight matrices
        W = 2*rand(Nr,Nr) - 1;
        W = rho * (W / max(abs(eig(W))));
        state = zeros(Nr,1);
        H = [];
        
        % run the reservoir on the input stream
        for t = 1:trainingSteps
            state = tanh(U * X_train(t) + W * state);
            H(:,end+1) = state;
        end
        % discard the washout
        H = H(:,Nr+1:end);
        % update the target matrix dimension
        D = Y_train(:,Nr+1:end);
        % train the readout
        V = D*H'*inv(H*H'+ l * eye(Nr));
        
        % compute the output and error (loss) for the training samples
        Y_tr = V * H;
        err_tr = immse(D,Y_tr);
        E_trs(end+1) = err_tr;
        
        state = zeros(Nr,1);
        H_val = [];
        % run the reservoir on the validation stream
        for t = 1:validationSteps
            state = tanh(U * X_val(t) + W * state);
            H_val(:,end+1) = state;
        end
        % compute the output and error (loss) for the validation samples
        Y_val = V * H;
        err_val = immse(D,Y_val);
        E_vals(end+1) = err_val;
       
    end
    error_tr = mean(E_trs);
    fprintf('Error on training set: %.5f\n', error_tr);
    error_val = mean(E_vals);
    ERS(end+1) = error_val;
    fprintf('Error on validation set: %.5f\n\n', error_val);
    fprintf('\n#%d/%d: ', g, size(grid,1));
end

[value, idx] = min(ERS);
fprintf('\nBest hyper-params:\nInput scaling: %.2f - Reservoir dimension: %d - Spectral radius: %.2f - Lambda: %.4f\nValidation error: %.5f\n', grid(idx,1), grid(idx,2), grid(idx,3), grid(idx,4), value);
% fprintf('\nBest hyper-params:\nInput scaling: %.2f - Reservoir dimension: %d Spectral radius: %.2f - Lambda: %.4f - Connectivity percentage: %.2f\nValidation error: %.5f\n', grid(idx,1), grid(idx,2), grid(idx,3), grid(idx,4), grid(idx,5), value);

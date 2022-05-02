function Build_C_code()


    addpath(genpath([pwd, filesep, 'algorithms']));
    addpath(genpath([pwd, filesep, 'dataPreparationAnalysis']));
    addpath(genpath([pwd, filesep, 'Examples']));
    addpath(genpath([pwd, filesep, 'GUI']));
    
    % This function biulds the required C MEX fucntions.
    % NOTE, b default matlab uses -o2 optimisations.
    % Chnaging this to -ofast reduces the doIRFconvolution.c
    % runtime from 0.017534s to 0.010353s on a x64 Linux maxtine (in 2018) (41% faster).
    %
    % To change the Linux compile settings open the file ~/.matlab/R2016a/mex_C_glnxa64.xml
    % and change:
    %   - 'COPTIMFLAGS="-O -DNDEBUG"' to 'COPTIMFLAGS="-Ofast -DNDEBUG"'
    %   - 'LDOPTIMFLAGS="-O"' to 'LDOPTIMFLAGS="-Ofast"'
    %
    % To chnage Windows Visual studio compier, open the file 
    % mex_C_win64.xml and chnage: 
    %  - 'OPTIMFLAGS="/Ofast /Oy- /DNDEBUG"' to 'OPTIMFLAGS="/O2 /Oy- /DNDEBUG"'

    arch=computer('arch');
    mexopts = {'-O' '-v' ['-' arch]};
    % 64-bit platform
    if ~isempty(strfind(computer(),'64'))
        mexopts(end+1) = {'-largeArrayDims'};
    end

    % invoke MEX compilation tool
    if ispc
        mex(mexopts{:},'algorithms\models\TransferNoise\ForcingTransformation\c');
        mex(mexopts{:},'algorithms\models\TransferNoise\doIRFconvolution.c');
        
        movefile('doIRFconvolution.mexw64', 'algorithms\models\TransferNoise\doIRFconvolution.mexw64')
        movefile('forcingTransform_soilMoisture.mexw64', 'algorithms\models\TransferNoise\ForcingTransformation\forcingTransform_soilMoisture.mexw64')

    else        
        mex(mexopts{:},'algorithms/models/TransferNoise/ForcingTransformation/forcingTransform_soilMoisture.c');
        mex(mexopts{:},'algorithms/models/TransferNoise/doIRFconvolution.c');        
        
        movefile('doIRFconvolution.mexa64', 'algorithms/models/TransferNoise')
        movefile('forcingTransform_soilMoisture.mexa64', 'algorithms/models/TransferNoise/ForcingTransformation')
    end

    
end


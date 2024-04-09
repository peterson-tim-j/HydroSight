function Build_C_code()

    % This function builds the required C MEX fucntions.
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
        mex(mexopts{:},'algorithms\models\TransferNoise\ForcingTransformation\forcingTransform_soilMoisture.c');
        mex(mexopts{:},'algorithms\models\TransferNoise\doIRFconvolution.c');
        mex(mexopts{:},'algorithms\models\ExpSmooth\doExpSmoothing.c');
               
        delete('algorithms\models\TransferNoise\doIRFconvolution.mexw64');
        delete('algorithms\models\TransferNoise\ForcingTransformation\forcingTransform_soilMoisture.mexw64');
        delete('algorithms\models\TransferNoise\ForcingTransformation\forcingTransform_soilMoisture.mexw64');

        movefile('doIRFconvolution.mexw64', 'algorithms\models\TransferNoise','f');
        movefile('forcingTransform_soilMoisture.mexw64', 'algorithms\models\TransferNoise\ForcingTransformation','f');
        movefile('doExpSmoothing.mexw64', 'algorithms\models\ExpSmooth','f');
    else        
        mex(mexopts{:},'algorithms/models/TransferNoise/ForcingTransformation/forcingTransform_soilMoisture.c');
        mex(mexopts{:},'algorithms/models/TransferNoise/doIRFconvolution.c');        
        mex(mexopts{:},'algorithms/models/ExpSmooth/doExpSmoothing.c');

        if ismac
            movefile('doIRFconvolution.mexmaci64', 'algorithms/models/TransferNoise','f');
            movefile('forcingTransform_soilMoisture.mexmaci64', 'algorithms/models/TransferNoise/ForcingTransformation','f');
            movefile('doExpSmoothing.mexmaci64', 'algorithms/models/ExpSmooth','f');
        elseif isunix
            movefile('doIRFconvolution.mexa64', 'algorithms/models/TransferNoise','f');
            movefile('forcingTransform_soilMoisture.mexa64', 'algorithms/models/TransferNoise/ForcingTransformation','f');
            movefile('doExpSmoothing.mexa64', 'algorithms/models/ExpSmooth','f');
        end
    end    
end


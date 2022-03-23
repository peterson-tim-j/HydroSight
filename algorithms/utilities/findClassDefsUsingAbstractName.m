function [classNames] = findClassDefsUsingAbstractName( abstractName, model_file_name)

    % Set some file names to ignore. This is undertaken because
    % requiredFilesAndProducts() (using matlab 2014b) appears to give inconsistent
    % results and for to reduce GUI start up time.
    fnames_ignore = {'model_TFN' ...
                     'example_TFN_model' ...
                     'HydroSight' ...
                     'ipdm' ...
                     'cmaes' ...
                     'fminsearchbnd' ...
                     'variogram' ...
                     'variogramfit' ...
                     'forcingTransform_abstract' ...
                     'derivedForcingTransform_abstract' ...
                     'stochForcingTransform_abstract' ...
                     'responseFunction_abstract' ...
                     'derivedResponseFunction_abstract' ...
                     'doIRFconvolution' ...
                     'findAbstractName' ...
                     'model_abstract'};
    fnames_ignore = unique([abstractName fnames_ignore ]);


    % Check 'abstractName' is an abstract class 
    classNames = {};
    if strcmp(abstractName,'handle')
        return;
    end
    
    metaclass = meta.class.fromName(abstractName);
    if any(strcmp(properties(metaclass),'Abstract'))
        try
            abstractNames{1} = metaclass.Name;
        catch ME
            abstractNames{1} = '';
        end
            
    else
        % Loop though all methods. If all methods are abstract, then 
        % 'abstractName' is deemed as an abstract classdef.
        isAbstract=true;
        for i=1:size( metaclass.Methods,1)
            if ~metaclass.Methods{i,1}.Abstract ...
            && ~strcmp(metaclass.Methods{i,1}.DefiningClass.Name, metaclass.Methods{i,1}.Name) ...
            && ~strcmp(metaclass.Methods{i,1}.DefiningClass.Name, 'handle')
                isAbstract=false;
                break;
            end
        end
        if ~isAbstract;
            return;
        end
    end
    
    % Find path to the specified model.
    if exist(model_file_name)
        modelPath = fileparts(which(model_file_name));        
    else
        error(['The following model file does not exist:',model_file_name]);
    end
    
    % Get list of all .m files listed within the model folder
    allFoldersFiles = rdir(fullfile(modelPath, ['**',filesep,'*.m']));
    
    % Get just the file names
    all_m_Files = cell( size(allFoldersFiles));
    for i=1:size(allFoldersFiles,1)
        [pathstr, name] = fileparts(allFoldersFiles(i).name);
        all_m_Files{i} = name;
    end
    
    isFileFromAbstract = false(size(allFoldersFiles));
    
    % Determine which version of depfun to use. Post Matlab 2014b, depfun
    % was removed.
    useDepFun = year(version('-date'))<=2014;
    
    % Loop through each file name and assess if the file is dependent on
    % the specified abstract
    for i=1:size(allFoldersFiles,1)

        if ~any(cellfun(@(x) ~isempty(x), strfind( fnames_ignore , all_m_Files{i})))            

           % Get list of dependent function                              
           if useDepFun
               depfunlist = depfun(all_m_Files(i),'-quiet');               
           else
               depfunlist = matlab.codetools.requiredFilesAndProducts(all_m_Files(i));
               depfunlist = depfunlist';                
           end

           % Find if there is dependence upon the required abstract name
           if any(cellfun(@(x) ~isempty(x), strfind( depfunlist, abstractName)))
               isFileFromAbstract(i) = true;               
           end
               
        end
    end
    
    % File the list of class names to those dependent upon the abstract
    classNames = all_m_Files(isFileFromAbstract)';
end


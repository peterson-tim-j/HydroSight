function [ abstractNames ] = findAbstractName( className )

    abstractNames = {};
    if strcmp(className,'handle')
        return;
    end
    
    metaclass = meta.class.fromName(className);
    if any(strcmp(properties(metaclass),'Abstract'))
        abstractNames{1} = metaclass.Name;
    else
        % Loop though all methods. If all methods are abstract, then the
        % class is deemed as an abstract classdef.
        isAbstract=true;
        for i=1:size( metaclass.Methods,1)
            if ~metaclass.Methods{i,1}.Abstract ...
            && ~strcmp(metaclass.Methods{i,1}.DefiningClass.Name, metaclass.Methods{i,1}.Name) ...
            && ~strcmp(metaclass.Methods{i,1}.DefiningClass.Name, 'handle')
                isAbstract=false;
                break;
            end
        end
        if isAbstract;
            abstractNames{1} = metaclass.Name;
        end
    end
    
    % Get names of superclasses. Note: The field names of chnages between
    % matlab 2010 and matlab 2014a. The following attempts to handle both
    % formats.
    if any(strcmp(properties(metaclass),'SuperclassList'))
        SuperclassList = metaclass.SuperclassList;
    elseif any(strcmp(properties(metaclass),'SuperClasses'))
        SuperclassList = metaclass.SuperClasses;
    end
        
    % Assign results to output cell array.
    for i=1:length(SuperclassList)
        if iscell(SuperclassList)
            tmp = findAbstractName( SuperclassList{i}.Name );            
        else
            tmp = findAbstractName( SuperclassList(i).Name );
        end
        if ~isempty(tmp)
            abstractNames(size(abstractNames,1)+1:size(abstractNames,1)+size(tmp,1),1) = tmp;
        end
    end

end


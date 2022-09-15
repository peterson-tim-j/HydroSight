classdef modelOptions < handle  
    %MODELOPTIONS Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        label
        options
        colNames
        colFormats
        colEdits
        TooltipString
    end
    
    methods
        function obj = modelOptions()
            obj.label = '';
            obj.options = {};
            obj.colNames = cell(0,1);
            obj.colFormats = cell(0,1);
            obj.colEdits = false;
            obj.TooltipString = '';
        end            
        
        function set.label(obj,input)
           if ischar(input)
               obj.label = input;
           else
               error('Model option "label" must be a string.')
           end
        end

        function output = get.label(obj)
           output = obj.label;
        end        
        
        function set.options(obj,input)
           if iscell(input)
               obj.options = input;
           else
               error('Model option "options" must be a cell array.')
           end
        end

        function output = get.options(obj)
           output = obj.options;
        end        
                
        function set.colNames(obj,input)
           if iscell(input)
               obj.colNames = input;
           else
               error('Model option "colNames" must be a cell array.')
           end
        end
        
        function output = get.colNames(obj)
           output = obj.colNames;
        end                
        
        function set.colFormats(obj,input)
           if iscell(input)
               obj.colFormats = input;
           else
               error('Model option "colFormats" must be a cell array.')
           end
        end      
        
        function output = get.colFormats(obj)
           output = obj.colFormats;
        end                        
        
        function set.colEdits(obj,input)
           if islogical(input)
               obj.colEdits = input;
           else
               error('Model option "colEdits" must be a logical array.')
           end
        end               
                
        function output = get.colEdits(obj)
           output = obj.colEdits;
        end                
        
        function set.TooltipString(obj,input)
           if ischar(input)
               obj.TooltipString = input;
           else
               error('Model option "TooltipString" must be a string.')
           end
        end

        function output = get.TooltipString(obj)
           output = obj.TooltipString;
        end         
    end
    
end


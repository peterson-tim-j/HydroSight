function [NewGen] = CheckPars(NewGen,ParRange,BoundHandling);
% Check whether parameters are in bound 
    
% Do boundary handling -- what to do when points fall outside bound
if strcmp(BoundHandling,'Reflect');
    [NewGen] = ReflectBounds(NewGen,ParRange);
end;
if strcmp(BoundHandling,'Bound');
    [NewGen] = SetToBounds(NewGen,ParRange);
end;
if strcmp(BoundHandling,'Fold');
    [NewGen] = FoldBounds(NewGen,ParRange);
end;
if strcmp(BoundHandling,'None');
    % Do nothing
end;
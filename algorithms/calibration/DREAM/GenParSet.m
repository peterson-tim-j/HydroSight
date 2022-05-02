function ParSet = GenParSet(chain);
% Generates a 2D matrix ParSet from 3D array chain

% Determine how many elements in chain
[T,d,N] = size(chain); 

% Initalize ParSet
ParSet = [];

% If save in memory -> No -- ParSet is empty
if (T == 0),
    % Do nothing
else
    % ParSet derived from all chain
    for qq = 1:N,
        ParSet = [ParSet; chain(:,:,qq) (1:size(chain(:,:,qq),1))'];
    end;
    ParSet = sortrows(ParSet,[d+1]); ParSet = ParSet(:,1:d);
end;
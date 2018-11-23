function [headData,noise_sigma, ARMA_params, exp_model] = doDataQualityAnalysis( headData, boreDepth, surface_elevation, casing_length, constuction_date, ...
   checkMinSartDate, checkMaxEndDate, chechDuplicateDates, checkMinHead, checkMaxHead, RateofChangeThreshold, ConstHeadThreshold, outlierNumStDevs, outlierForwadBackward)
%EXPORTDATATABLE Summary of this function goes here
%   Detailed explanation goes here

    % Handle situation where outlierForwadBackward is not set.
    if nargin <14
        outlierForwadBackward = true;
    end

    % Minimum number of non-errorous observations required for undertaking
    % ARAM outlier detection;
    minObsforOutlierDetection = 12;

    % Duration for constant head error checkd min ob 
    constHeadThreshold_minObs = 3;
    
    % Assign plausible dates for water level obs    
    plausibleEndDate = now();    
    
    errCode = -9999.99;
    
    % Check there is enough data to run the analysis
    if size(headData,1)<=1
        return;
    end
    
    
    % Sort by date 
    headData = sortrows(headData,1);

    % Convert the table data to arrays
    if istable(headData)
        headData = headData{:,[1:2]};
    end

    % Filter for plausible dates
    filt_date = false(size(headData,1),1);
    if checkMinSartDate
        filt_date = headData(:,1) < constuction_date;
    end
    if checkMaxEndDate
        filt_date = headData(:,1)>now() | filt_date;
    end    
    isErrorObs = filt_date;

    % Filter date duplicates
    filt_duplicates = false(size(headData,1),1);
    if chechDuplicateDates
        timeStep = [diff( headData(:,1)); inf];
        filt_duplicates = abs(timeStep) <sqrt(eps);    
        filt_duplicates(isErrorObs) = false;        
    end
    isErrorObs = filt_date | filt_duplicates;

    % Check head is above the bottom of the bore.
    filt_minHead = false(size(headData,1),1);
    if checkMinHead                    
        filt_minHead_tmp = headData(~isErrorObs,2) < surface_elevation - boreDepth;        
        filt_minHead(~isErrorObs ) = filt_minHead_tmp;
        clear filt_minHead_tmp;    
    end
    isErrorObs = filt_date | filt_duplicates | filt_minHead;

    
    % Check the head is below the top of the casing (assumes the aquifer is
    % unconfined)
    filt_maxHead = false(size(headData,1),1);
    if checkMaxHead
        filt_maxHead_tmp = headData(~isErrorObs,2) > surface_elevation + casing_length;        
        filt_maxHead(~isErrorObs ) = filt_maxHead_tmp;
        clear filt_maxHead_tmp;
    end
    isErrorObs = filt_date | filt_duplicates | filt_minHead | filt_maxHead;

    
    % Filter for rapd change in headData
    filt_rapid = false(size(headData,1),1);    
    d_headData_dt = diff( headData(~isErrorObs,2))./ diff( headData(~isErrorObs,1));
    filt_rapid(~isErrorObs) = [false; abs(d_headData_dt) >= RateofChangeThreshold];          
    isErrorObs = filt_date | filt_duplicates | filt_minHead | filt_maxHead | filt_rapid;
            
    % Filter out bore with a constant head for > 'ConstHeadThreshold' days. First the
    % duration of 'flat' periods is assessed.
    filt_flatExtendedDuration = false(size(isErrorObs,1),1);
    if RateofChangeThreshold>0
        headData_tmp = headData(~isErrorObs,:);    
        delta_headData_fwd = [false; headData_tmp(2:end,2) - headData_tmp(1:end-1,2)];
        delta_headData_rvs = [headData_tmp(1:end-1,2) - headData_tmp(2:end,2); false];
        filt_flat = delta_headData_fwd==0 | delta_headData_rvs==0;
        if any(filt_flat)

            filt_flatExtendedDuration_tmp = false(sum(~isErrorObs),1);

            % Filt out prior identified errors
            headData_filt = headData(~isErrorObs,:);

            startDate = 0;
            endDate = 0;
            startheadData = nan;
            for j=2:size(headData_filt,1)
                try
                    if (filt_flat(j) && ~filt_flat(j-1)) || (j==2 && filt_flat(j))
                        if j==2 && filt_flat(j-1)
                            startDate = headData_filt(j-1,1)-sqrt(eps());
                            startheadData = headData_filt(j-1,2);
                        else
                            startDate = headData_filt(j,1);
                            startheadData = headData_filt(j,2);
                        end                            
                        endDate = 0;                            
                    elseif startDate>0 && (~filt_flat(j) || j==size(headData_filt,1) || headData_filt(j,2)~=startheadData) 
                        endDate = headData_filt(j,1);
                        if j==size(headData_filt,1) && headData_filt(j,2)==headData_filt(j-1,2)
                            endDate = endDate+sqrt(eps());
                        end

                        % Assess if the zero period is >60 days long
                        % and are > constHeadThreshold_minObs
                        filt_tmp = headData_filt(:,1)>= startDate & headData_filt(:,1) < endDate;
                        consHead_dates =  headData_filt(filt_tmp,1);
                        if  consHead_dates(end) - consHead_dates(1) >= ConstHeadThreshold ...
                        &&  sum(filt_tmp)>=constHeadThreshold_minObs       
                            filt_flatExtendedDuration_tmp(filt_tmp) = true;
                        end    

                        % Reset markers
                        startDate = 0;
                        endDate = 0;   
                        startheadData = nan;                            
                    end
                catch
                   display('err'); 
                end
            end     
            filt_flatExtendedDuration = false(size(isErrorObs,1),1);
            filt_flatExtendedDuration(~isErrorObs) = filt_flatExtendedDuration_tmp;
        end
    end

    % Aggregare Errors filters
    isErrorObs = filt_date | filt_duplicates | filt_minHead | filt_maxHead | filt_rapid | filt_flatExtendedDuration;  


    % Detect remaining outliers using a calibrated ARMA(1) model.            
    if sum(~isErrorObs)>minObsforOutlierDetection && outlierNumStDevs>0
        try
            % Analyse outliers in forward time.
            [ isOutlierObs_forward, noise_sigma, ARMA_params, exp_model ] = outlierDetection(  headData, isErrorObs, outlierNumStDevs);
            isOutlierObs = isOutlierObs_forward; 
            
            if outlierForwadBackward
                % Analyse outliers in reverse time.
                headData_reverse = headData(size(headData,1):-1:1,:);
                headData_reverse(:,1) = headData(end,1) - headData_reverse(:,1);
                isOutlierObs_reverse = outlierDetection(  headData_reverse, isErrorObs, outlierNumStDevs);
                isOutlierObs_reverse = isOutlierObs_reverse(size(headData,1):-1:1,:);            

                % Define as outlier if detected forward and reverse in time.
                isOutlierObs = isOutlierObs_forward & isOutlierObs_reverse;
            end
        catch ME
            display(['    WARNING: Outlier detection failed.']); 
            isOutlierObs = false(size(isErrorObs));
            noise_sigma = [];
            ARMA_params = [];           
            exp_model = [];
        end
    else
        isOutlierObs = false(size(isErrorObs));
        noise_sigma = [];
        ARMA_params = [];                
        exp_model = [];
    end


    % Delete calibration data files
    delete('*.dat');
    
    % Aggregate the logical data from the analyis into a table and combine
    % with the observated data.
    headData = table(year(headData(:,1)), month(headData(:,1)), day(headData(:,1)), hour(headData(:,1)), minute(headData(:,1)), headData(:,2), filt_date, filt_duplicates, filt_minHead, filt_maxHead, filt_rapid, filt_flatExtendedDuration, isOutlierObs, ...
        'VariableNames',{'Year', 'Month', 'Day', 'Hour', 'Minute', 'Head', 'Date_Error', 'Duplicate_Date_Error', 'Min_Head_Error','Max_Head_Error','Rate_of_Change_Error','Const_Hear_Error','Outlier_Obs'});

end


                   
                

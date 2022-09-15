function gif2data()
%GIF2DATA Convert gif icons to data
%   gif icons concerted to data to avoid GUI use of image processing toolbox.

    icon = 'implay_export.gif';
    [cdata,map] = imread(icon);
    map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
    cdata = ind2rgb(cdata,map);
    iconData.implay = cdata;
    
    icon = 'foldericon.gif';
    [cdata,map] = imread(icon);
    map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
    cdata = ind2rgb(cdata,map);
    iconData.folder = cdata;
    
    % Add new button for help.
    icon = 'helpicon.gif';
    [cdata,map] = imread(icon);
    map(find(map(:,1)+map(:,2)+map(:,3)==3)) = NaN;
    cdata = ind2rgb(cdata,map);
    iconData.help = cdata;

    save('iconData.mat',"iconData");  

    % Import and save app icon
    iconData = javax.swing.ImageIcon('icon16x16.png');
    save('appIcon.mat',"iconData");  

end


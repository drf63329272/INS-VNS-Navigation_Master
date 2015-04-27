% buaaxyz 2014.1.7

% 裁剪当前目录下的所有图片到一定尺寸

function cutImage()
resolutionStr=inputdlg({'裁剪目标分辨率'},'裁剪',1,{'1392 1040'});
if isempty(resolutionStr)
   return; 
end
resolution = sscanf(resolutionStr{1},'%f');
imageName = ls([pwd,'\*.bmp']);
imageNum = size(imageName,1);
wh=waitbar(0,'图片裁剪中');
for k=1:imageNum
   image_k = imread([pwd,'\',imageName(k,:)]); 
   image_k = image_k(1:resolution(2),1:resolution(1),:);
   imwrite(image_k,[pwd,'\',imageName(k,:)],'bmp')
   waitbar(k/imageNum)
end
close(wh)
disp('OK')


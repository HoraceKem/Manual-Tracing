function [surfname,surfdata]=scanvastsurfacefile(filename)
%A script to parse surface stats files saved by VastTools.
%By Daniel Berger, September 2018

fid = fopen(filename);
tline = fgetl(fid);
y=1;
while ischar(tline)
  if ((numel(tline)>0)&&(tline(1)~='%'))
    idx=find(tline=='"',1,'first');
    tline2=tline(idx+1:end);
    idx=find(tline2=='"',1,'first');
    n=tline2(1:idx-1);
    tline3=tline2(idx+1:end);
    [a,count,errmsg,nextindex]=sscanf(tline3, '  %ld   %f');
    surfdata(y,:)=a';
    surfname{y}=n;
    y=y+1;
  end;
  tline = fgetl(fid);
end;
fclose(fid);
  
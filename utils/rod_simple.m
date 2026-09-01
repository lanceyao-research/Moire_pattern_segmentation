function ZMap = rod_simple(RES,sz,h)
%RES = 256;   %RES requested image size (px)
%sz = 200;    %sz rod head diameter (px)
%h = 300;     %h rod height (px), should be larger than sz!
rd = sz/2;
XMap = repmat(1:RES,RES,1)-RES/2;
YMap = repmat((1:RES)',1,RES)-RES/2;
ZMap = rd^2-(XMap.^2+YMap.^2);
torso = (ZMap>0)*(h - sz);
ZMap(ZMap<0) = 0;
ZMap = sqrt(ZMap)*2+torso;
end
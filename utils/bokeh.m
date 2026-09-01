function result=bokeh(thicknessMap,r)
    f = fspecial('disk', r);
    result = imfilter(thicknessMap,f);
end

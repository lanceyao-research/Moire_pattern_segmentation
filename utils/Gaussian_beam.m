function intensity = Gaussian_beam()

    decay = 2+abs(normrnd(0,3));
    x = linspace(-1,1,512)-0.3+rand()*0.6;
    y = linspace(-1,1,512)-0.3+rand()*0.6;
    [X,Y] = meshgrid(x,y);
    intensity = exp(-(X.^2 + Y.^2)/decay);

end
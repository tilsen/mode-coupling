function [vec] = onehot(ix,len)

vec = false(1,len);
vec(ix) = true;

end
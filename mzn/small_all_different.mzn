% --- small_alldifferent.mzn ---
include "all_different.mzn";
%array[1..4] of var 1..10: x;
array[1..4] of var 1..6: y;
%constraint all_different(x);
constraint all_different(y);

constraint y[1] > y[2];

%constraint y[1] + y[2] <= 0;

solve maximize y[1] + y[2];
% ------------------------------
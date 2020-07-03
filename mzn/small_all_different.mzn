% --- small_alldifferent.mzn ---
include "all_different.mzn";
array[1..4] of var 1..10: x;
constraint all_different(x);
% ------------------------------
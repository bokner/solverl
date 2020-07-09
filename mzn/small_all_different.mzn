% --- small_alldifferent.mzn ---
include "all_different.mzn";
int: test_data;
%array[1..4] of var 1..10: x;
array[1..4] of var 1..6: y;
var 1..3: z;

var set of 0..4: test_set;
%constraint all_different(x);
constraint all_different(y);

constraint y[1] > y[2];

%constraint y[1] + y[2] <= 0;

solve maximize y[1] + y[2];
% ------------------------------
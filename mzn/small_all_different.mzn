% --- small_alldifferent.mzn ---
include "all_different.mzn";
int: test_data1;
int: test_data2;

array[1..2, 1..3, 1..3] of int: test_arr;

array[0..1, 1..3, 0..2] of int: test_base_arr;

%% Test sets
set of int: test_set;

%% Test enums
enum test_enum;

%array[1..4] of var 1..10: x;
array[1..4] of var 1..6: y;
var 1..3: z;

var set of 0..4: test_var_set;
%constraint all_different(x);
constraint all_different(y);

constraint y[1] > y[2];

%constraint y[1] + y[2] <= 0;

solve maximize y[1] + y[2];

output ["test data: \(test_arr)\n"];
%output ["y = \(y)"];
% ------------------------------
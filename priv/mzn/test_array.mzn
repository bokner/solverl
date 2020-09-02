array[1..4, 1..5] of var 0..1: arr;

constraint forall(i in 1..4)(
  forall(j in 1..4)(
    arr[i, j] != arr[i, j+1]
    )
);
    include "globals.mzn";
    int: n;
    int: n_edges;
    int: upper_bound = n;
    int: lower_bound = 2;

    set of int: VERTEX = 0..n-1;
    set of int: EDGE = 1..n_edges;
    set of int: COLOR = 0..upper_bound - 1;

    array[EDGE, 1..2] of int: edges;

    %Auxillary

    array[VERTEX] of var COLOR: colors;

    array[COLOR] of var set of VERTEX: vertex_sets;

    var lower_bound..upper_bound: chromatic;

     array[1..upper_bound] of var int: cards = [card(v) | v in vertex_sets];


    constraint int_set_channel(colors, vertex_sets);

    constraint forall(i in EDGE)
                (colors[edges[i,1]] != colors[edges[i,2]] );



    %% Objectives
    constraint chromatic = %sum(c in cards)(c > 0);
                          1 + max(colors);
    var 2..n: independence = max(cards);

    var 2..n: avg_independence = sum(cards) div chromatic;

    constraint chromatic*avg_independence <= n;
    constraint chromatic*independence >= n;

annotation relax_and_reconstruct(array[int] of var int,int);
annotation restart_luby(int);

int: lns = 60;

    solve :: seq_search([
                    int_search(colors, dom_w_deg, indomain_random, complete),
                    int_search([chromatic],  dom_w_deg, indomain_min, complete),
                    int_search(cards, dom_w_deg, indomain_random, complete),
                    int_search([independence],  dom_w_deg, indomain_max, complete)
                        ])
            %:: relax_and_reconstruct(colors, lns)
            %:: restart_luby(100)
       minimize chromatic;



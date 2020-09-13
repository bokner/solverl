include "globals.mzn";


int: n; % Number of customers
int: m; % Maximum number of vehicles
int: DEPOT = n+1;
set of int: CUSTOMERS = 1..n+1;
set of int: NOTDEPOT = 1..n; % all customers, depot excluded
set of int: VEHICLES = 1..m;

set of int: LOAD = 0..capacity;
int: capacity; % Capacity of each vehicle
int: total_demand = sum(demand);

array[CUSTOMERS,CUSTOMERS] of int: distance; % Distance between customers
array[CUSTOMERS] of int: demand; % Demand of each customer

array[VEHICLES,CUSTOMERS] of var CUSTOMERS: succ; % succ[v,c] is a customer vehicle v visits after customer c

% vehicle_assignment[v, c] = 1 <-> vehicle v assigned to customer c
array[VEHICLES, CUSTOMERS] of var 0..1: vehicle_assignment;

var ceil(total_demand/capacity)..m: vehiclesUsed;
%constraint total_demand <= capacity*vehiclesUsed;

int: min_distance = min([distance[i,j] | i,j in 1..n where i < j]);
int: max_distance = max([distance[i,j] | i,j in 1..n where i < j]);

int: max_tour = sum([distance[i,j] | i,j in 1..n where i < j]);
var 0..max_tour: distanceTravelled;

% Max of stops/customers per vehicle.
int: max_stops;



constraint forall(v in VEHICLES, c in CUSTOMERS)(
    (succ[v,c] != c) = vehicle_assignment[v, c]
    );

%% Vehicle tours do not intercept and include all customers
%%
% One vehicle per customer
constraint forall(c in NOTDEPOT)(
  sum(vehicle_assignment[.., c]) = 1
);

% All vehicles have a depot in their routes
constraint sum(vehicle_assignment[.., DEPOT]) = vehiclesUsed;

% Breaking symmetry: put vehicles in lexicographic order.
%constraint forall(v in 1..m-1)(lex_greatereq(vehicle_assignment[v, ..], vehicle_assignment[v+1, ..]));

%constraint seq_precede_chain(vehicle_load);



constraint forall(v in VEHICLES)(subcircuit(succ[v, ..]));

%% Load and capacity

% Declaration enforces the load of vehicle less or equal of it's capacity.
array[VEHICLES] of var LOAD: vehicle_load;

constraint forall(v in VEHICLES)(
  vehicle_load[v] = sum(c in NOTDEPOT)(vehicle_assignment[v, c] * demand[c])
);

var total_demand..m*capacity: total_load;

constraint total_load = sum(vehicle_load);

%% Customers per vehicle
%% TODO: Calculate max number of customers per vehicle based on demand.
array[VEHICLES] of var NOTDEPOT: vehicle_customer_count;

constraint forall(v in VEHICLES)(
    vehicle_customer_count[v] = sum(vehicle_assignment[v, ..])
);

constraint sum(vehicle_customer_count) = n + vehiclesUsed;

array[VEHICLES] of var int: vehicle_distance;

constraint forall(v in VEHICLES)(
  vehicle_distance[v] =
          sum(c in CUSTOMERS
          )
            (distance[c, succ[v,c]])
);

constraint vehiclesUsed = sum(d in vehicle_load)(d > 0);

%% Constraints that presumably improve propagation
% constraint forall(v in VEHICLES)(
%    vehicle_assignment[v, succ[v, DEPOT]] = 1
% );

constraint distanceTravelled =
           sum(vehicle_distance);

%include "gecode.mzn";

annotation relax_and_reconstruct(array[int] of var int,int);
annotation restart_luby(int);

%%%%%%% LHS
int: lns = if n in {199} then 67
              elseif n in {100} then 65
              elseif n in {15, 25} then 45
              elseif n in {50} then 58
              elseif n = 420 then 75
              else 50 endif;

int: restart = 100;


ann: search;

ann: first_search_clause;

%first_search_clause =  int_search(array1d(succ)  ++ vehicle_load
%          , afc_size_min, indomain_median);

 first_search_clause =  int_search(array1d(succ)  %++ vehicle_load
   %++ vehicle_customer_count
           , first_fail, indomain_split);

% first_search_clause =  int_search(array1d(succ)  ++ vehicle_load
%           , afc_size_max, indomain_median);


search =
  seq_search([

          first_search_clause,
              %int_search(vehicle_customer_count, max_regret, indomain_random),
          %
          int_search(vehicle_distance, first_fail, indomain_split),
          int_search([distanceTravelled], input_order, indomain_min),


          ]);

solve:: search
          :: relax_and_reconstruct(array1d(succ)
                                              % ++ array1d(vehicle_assignment)
                                              %++ vehicle_load
                                              %++ vehicle_customer_count
          , lns)
          :: restart_luby(restart)
          minimize distanceTravelled;




% output ["\(succ[v,c])" ++ if c = DEPOT then "\n" elseif c = m then "  " else "," endif | v in VEHICLES, c in CUSTOMERS];

% output ["\n\n"] ++ ["\(vehicle_assignment[v,c])" ++ if c = DEPOT then "\n" elseif c = m then "  " else "," endif | v in VEHICLES, c in CUSTOMERS];
%output ["\(vehicle_assignment[v, succ[v, 1]])::" ++ "\(succ[v, 1])"++ "\n"  | v in VEHICLES];
%output["\nvehicle assignment = \(vehicle_assignment)\n"];
%output["vehicles used = \(vehiclesUsed)\n"];
%output["customers: \(n), vehicles: \(m)\n"];
%output["LNS: \(lns), restart: \(restart)\n"];
%output["distance travelled = \(distanceTravelled)\n"];
%output["customers/vehicle=\(vehicle_customer_count)\n"];
%output["load=\(vehicle_load)\n"];

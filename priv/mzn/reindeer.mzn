% 
% Reindeer Ordering in MiniZinc.
% 
% This MiniZinc model was created by Hakan Kjellerstrand, hakank@gmail.com
%  (https://github.com/hakank/hakank/blob/af12fe43336959cdecfd856681b41528deb93654/minizinc/reindeer_ordering.mzn)
% Modified by Boris Okner, boris.okner@gmail.com 
% (to handle output of the model by host code rather than within the model) 
% 
% 
% From https://dmcommunity.org/challenge/challenge-dec-2017/
% """
% Santa always leaves plans for his elves to determine the order in which the 
% reindeer will pull his sleigh. This year, for the European leg of his 
% journey, his elves are working to the following schedule, which will form a 
% single line of nine reindeer. 
%
% Here are the rules:
%
%     Comet behind Rudolph, Prancer and Cupid
%     Blitzen behind Cupid
%     Blitzen in front of Donder, Vixen and Dancer
%     Cupid in front of Comet, Blitzen and Vixen
%     Donder behind Vixen, Dasher and Prancer
%     Rudolph behind Prancer
%     Rudolph in front of Donder, Dancer and Dasher
%     Vixen in front of Dancer and Comet
%     Dancer behind Donder, Rudolph and Blitzen
%     Prancer in front of Cupid, Donder and Blitzen
%     Dasher behind Prancer
%     Dasher in front of Vixen, Dancer and Blitzen
%     Donder behind Comet and Cupid
%     Cupid in front of Rudolph and Dancer
%     Vixen behind Rudolph, Prancer and Dasher.
%
% """

% Answer: prancer, cupid, rudolph, dasher, blitzen, vixen, comet, donder, dancer

set of int: reindeer  = 1..9;

% decision variables
var reindeer: Blitzen;
var reindeer: Comet;
var reindeer: Cupid;
var reindeer: Dancer;
var reindeer: Dasher;
var reindeer: Donder;
var reindeer: Prancer;
var reindeer: Rudolph;
var reindeer: Vixen;   

% x is behind all elements in y
predicate behind(var int: x, var set of int: y) = forall(i in y) ( x > i );

% x is in front of all elements in y
predicate in_front_of(var int: x, var set of int: y) = forall(i in y) ( x < i );

solve satisfy;

constraint
  Comet `behind` {Rudolph,Prancer, Cupid} /\
  Blitzen `behind` {Cupid} /\
  Blitzen `in_front_of` {Donder,Vixen,Dancer} /\
  Cupid `in_front_of` {Comet, Blitzen,Vixen} /\
  Donder `behind` {Vixen, Dasher, Prancer} /\
  Rudolph `behind` {Prancer} /\
  Rudolph `in_front_of` {Donder, Dancer, Dasher} /\
  Vixen `in_front_of` {Dancer,Comet} /\
  Dancer `behind` {Donder, Rudolph,Blitzen} /\
  Prancer `in_front_of` {Cupid, Donder, Blitzen} /\
  Dasher `behind` {Prancer} /\
  Dasher `in_front_of` {Vixen, Dancer, Blitzen} /\
  Donder `behind` {Comet,Cupid} /\
  Cupid `in_front_of` {Rudolph,Dancer} /\
  Vixen `behind` {Rudolph, Prancer, Dasher}
;


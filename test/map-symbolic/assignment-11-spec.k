// Copyright (c) 2019 K Team. All Rights Reserved.
// generated by gen-tests.sh

requires "map-tests.k"

module VERIFICATION
    imports MAP-TESTS
endmodule

module ASSIGNMENT-11-SPEC
    imports VERIFICATION

    claim <k> assignment ( (MAP:Map X:MyId |-> 1) [ Y:MyId <- 2 ] [ Z:MyId <- 3 ] ) => . </k> requires Y =/=K X andBool Z =/=K Y andBool notBool Y in_keys(MAP) andBool Z in_keys(MAP)

endmodule

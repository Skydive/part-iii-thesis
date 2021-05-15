package FPAddTest;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
import Cur_Cycle  :: *;

typedef FloatingPoint#(8,23) FSingle;
typedef Tuple2#( FSingle, FloatingPoint::Exception ) FpuR;

(* synthesize *)
module mkFPAddTest(Empty);

   Reg#(UInt#(8)) cycle <- mkReg(0);
   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR ) fpu_add <- mkFloatingPointAdder;

   rule rl_cycle(cycle < 255);
      cycle <= cycle + 1;
   endrule

   rule rl_start(cycle == 0);
      FSingle opd1 = 1.0;
      FSingle opd2 = -2.0;
      fpu_add.request.put(tuple3(opd1, opd2, defaultValue));
      $display("%0d: Start", cur_cycle);
   endrule

   rule rl_end;
      match { .res, .exc } <- fpu_add.response.get ();
      $display("%0d: Result: %h", cur_cycle, pack(res)); // OUTPUT
      $finish(0);
   endrule

endmodule
endpackage

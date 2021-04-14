package DivideTest;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
// https://github.com/B-Lang-org/bsc/blob/master/src/Libraries/Base3-Math/FloatingPoint.bsv
// https://github.com/bluespec/Flute/blob/master/src_Core/CPU/FPU.bsv
import Divide :: *;
import ConfigReg :: *;

typedef FloatingPoint#(8,23) FSingle;
typedef Tuple2#( FSingle, FloatingPoint::Exception ) FpuR;

(* synthesize *)
module mkDivideTest(Empty);

   Reg#(UInt#(8)) r_count <- mkReg(0);
   Reg#(UInt#(8)) m_count <- mkReg(0);
   
   Server# (Tuple4# (Maybe# (FSingle), FSingle, FSingle, RoundMode)
            , FpuR ) fpu_madd <- mkFloatingPointFusedMultiplyAccumulate;

   Server# (Tuple2# (UInt #(56), UInt #(28))
            , Tuple2# (UInt #(28), UInt #(28))) _div <- mkDivider(1);
   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR) fpu_div <- mkFloatingPointDivider(_div);
   
   ConfigReg#(FSingle) acc <- mkConfigReg(0.0);

   rule start (r_count == 0);
      FSingle opd1 = 1.0;
      FSingle opd2 = -2.0;
      $display("Multiply:");
      $display("opd1: ", fshow(opd1));
      $display("opd2: ", fshow(opd2));
      fpu_madd.request.put (tuple4(Valid(acc), opd1, opd2, defaultValue) );

      $display("Divide:");
      $display("opd1: ", fshow(opd1));
      $display("opd2: ", fshow(opd2));
      fpu_div.request.put (tuple3 (opd1, opd2, defaultValue) );
   endrule

   rule cycle(r_count < 255);
      r_count <= r_count + 1;
   endrule

   rule pipe_response_mul;
      match { .res, .exc } <- fpu_madd.response.get ();
      
      acc <= res;
      $display("Mul Result: %h", pack(res));
      $display("Count: %d", r_count);
      m_count <= m_count + 1;
   endrule
   
   rule pipe_response_mul_2(m_count == 1);
      m_count <= m_count + 1;
      FSingle opd1 = 1.0;
      FSingle opd2 = -2.0;
      fpu_madd.request.put (tuple4(Valid(acc), opd1, opd2, defaultValue) );
   endrule

   rule pipe_response_div;
      FpuR res <- fpu_div.response.get ();
      $display("Div Result: ", fshow(tpl_1(res)));
      $display("Count: %d", r_count);
   endrule

endmodule
endpackage

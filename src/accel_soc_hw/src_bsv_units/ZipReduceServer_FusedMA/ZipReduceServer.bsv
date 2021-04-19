package ZipReduceServer;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
// https://github.com/B-Lang-org/bsc/blob/master/src/Libraries/Base3-Math/FloatingPoint.bsv
// https://github.com/bluespec/Flute/blob/master/src_Core/CPU/FPU.bsv
import ConfigReg :: *;

typedef FloatingPoint#(8,23) FSingle;
typedef Tuple2#( FSingle, FloatingPoint::Exception ) FpuR;


import RegFile :: *;
import Memory :: *;

import Vector :: *;
import FIFOF :: *;

typedef enum {
   STATE_READY,
   STATE_LOCK,
   STATE_COMPLETE
   } AccState deriving (Bits, Eq);


typedef union tagged {
   UInt#(16) Init;
   Tuple2#(FSingle, FSingle) ReqOp;
   } MRequestUT deriving (Eq, Bits);


Integer max_alloc_size = 32;

(* synthesize *)
module mkZipReduceServer(Server#(MRequestUT, FSingle));
   Reg#(UInt#(32)) m_count <- mkReg(0);
   ConfigReg#(AccState) state <- mkConfigReg(STATE_READY);

   Server# (Tuple4# (Maybe# (FSingle), FSingle, FSingle, RoundMode)
            , FpuR ) fpu_madd <- mkFloatingPointFusedMultiplyAccumulate;

   ConfigReg#(FSingle) acc <- mkConfigReg(0.0);
   Reg#(UInt#(32)) alloc_size <- mkReg(0);

   rule rl_pipe_response_madd;
      match { .res, .exc } <- fpu_madd.response.get ();
      acc <= res;
      $display("%3d:%2d: MulAcc Result: %h", $time, m_count, pack(res));
      if(m_count == alloc_size-1) begin
         state <= STATE_COMPLETE;
         $display("%3d: STATE_COMPLETE", $time);
         m_count <= 0;
      end else begin
         $display("%3d: STATE_READY", $time);
         state <= STATE_READY;
         m_count <= m_count + 1;
      end
   endrule
   
   interface Put request;
      method Action put(MRequestUT m) if (state == STATE_READY);
         if(m matches tagged ReqOp .r) begin
            match { .opd1, .opd2 } = r;
            $display("%3d: PUT: %h %h %h", $time, acc, opd1, opd2);
            fpu_madd.request.put (tuple4(Valid(acc), opd1, opd2, defaultValue) );
            state <= STATE_LOCK;
            $display("%3d: STATE_LOCK", $time);
         end else if(m matches tagged Init .a) begin
            $display("%3d: Init", $time);
            alloc_size <= extend(a);
            acc <= 0;
            m_count <= 0;
         end
      endmethod
   endinterface
   interface Get response;
      method ActionValue#(FSingle) get() if (state == STATE_COMPLETE);
         state <= STATE_READY;
         return acc;
      endmethod
   endinterface
endmodule
endpackage

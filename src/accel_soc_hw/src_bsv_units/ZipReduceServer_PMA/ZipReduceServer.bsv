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
   STATE_MULTIPLY,
   STATE_ACCUMULATE,
   STATE_ADDING,
   STATE_COMPLETE
   } AccState deriving (Bits, Eq);

typedef union tagged {
   UInt#(16) Init;
   Tuple2#(FSingle, FSingle) ReqOp;
   } MRequestUT deriving (Eq, Bits);




Integer max_alloc_size = 128;

(* synthesize *)
module mkZipReduceServer(Server#(MRequestUT, FSingle));
   Reg#(Bit#(32)) r_count <- mkReg(0);
   Reg#(Bit#(32)) m_count <- mkReg(0);
   ConfigReg#(AccState) state <- mkConfigReg(STATE_READY);

   Server# (Tuple4# (Maybe# (FSingle), FSingle, FSingle, RoundMode)
            , FpuR ) fpu_madd <- mkFloatingPointFusedMultiplyAccumulate;
   Server# (Tuple3#(FSingle, FSingle, RoundMode)
            , FpuR ) fpu_add <- mkFloatingPointAdder;

   ConfigReg#(FSingle) acc <- mkConfigReg(0.0);

   Reg#(Bit#(32)) alloc_size <- mkReg(fromInteger(max_alloc_size));
   Vector#(32, Reg#(FSingle)) out <- replicateM(mkReg(0));

   rule rl_pipe_response_mul(state == STATE_MULTIPLY && m_count < alloc_size);
      match { .res, .exc } <- fpu_madd.response.get ();
      out[m_count] <= res;
      //$display("%3d:%2d: Mul Result: %h", $time, m_count, pack(res));
      m_count <= m_count + 1;
   endrule

   rule rl_end_multiply(state == STATE_MULTIPLY && m_count == alloc_size);
      m_count <= 0;
      //$display("%3d: STATE_ACCUMULATE", $time);
      state <= STATE_ACCUMULATE;
   endrule

   rule rl_start_acc(state == STATE_ACCUMULATE);
      //$display("ADD CMD: %h %h", pack(acc), pack(out[m_count]));
      fpu_add.request.put (tuple3(acc, out[m_count], defaultValue));
      state <= STATE_ADDING;
      m_count <= m_count + 1;
   endrule

   rule rl_pipe_response_add(state == STATE_ADDING);
      match { .res, .exc } <- fpu_add.response.get ();
      acc <= res;
      //$display("%3d:%2d: Add Result: %h", $time, m_count, pack(res));
      if(m_count == alloc_size) begin
         state <= STATE_COMPLETE;
         //$display("%3d: STATE_COMPLETE", $time);
         r_count <= 0;
         m_count <= 0;
      end else begin
         state <= STATE_ACCUMULATE;
      end
   endrule
   
   interface Put request;
      method Action put(MRequestUT m) if (state == STATE_READY || state == STATE_MULTIPLY);
         if(m matches tagged ReqOp .r) begin
            match { .opd1, .opd2 } = r;
            //$display("%d: PUT: ", $time, fshow(opd1), fshow(opd2));
            fpu_madd.request.put (tuple4(Invalid, opd1, opd2, defaultValue) );
            r_count <= r_count + 1;
         end
         else if(m matches tagged Init .a) begin
            //$display("%3d: Init", $time);
            alloc_size <= extend(pack(a));
            acc <= 0;
            r_count <= 0;
            m_count <= 0;
            //$display("%3d: STATE_MULTIPLY", $time);
            state <= STATE_MULTIPLY;
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

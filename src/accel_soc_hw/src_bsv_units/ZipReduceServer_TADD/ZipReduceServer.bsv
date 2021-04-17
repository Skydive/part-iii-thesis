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

   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR ) fpu_mult <- mkFloatingPointMultiplier;
   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR ) fpu_add <- mkFloatingPointAdder;

   ConfigReg#(FSingle) acc <- mkConfigReg(0.0);
   Reg#(UInt#(32)) alloc_size <- mkReg(0);

   Vector#(128, Reg#(Maybe#(FSingle))) buffer <- replicateM(mkReg(Invalid));
   
   // Rule, do multiply
   rule rl_pipe_response_mult (m_count < alloc_size);
      match { .res, .exc } <- fpu_mult.response.get ();
      buffer[m_count] <= Valid(res);
      $display("%3d:%2d: MulAcc Result: %h", $time, m_count, pack(res));
   endrule
   // Rules, do add
   Reg#(UInt#(8)) add_count <- mkReg(0);
   Reg#(UInt#(8)) add_range <- mkReg(0);
   rule rl_request_tree_add (m_count < add_range*2);
      let m1 = buffer[a_count];
      let m2 = buffer[a_count+1];
      if(m1 matches tagged Valid .f1 && matches tagged Valid .f2) begin
         fpu_add.request.put(tuple3(f1, f2, defaultValue));
         m1 <= Invalid;
         m2 <= Invalid;
         a_count <= a_count + 2;
      end
   endrule
   
   Reg#(FSingle) 
   rule rl_response_tree_add;
      match { .res, .exc } <- fpu_add.response.get ();
      buffer[m]
      
   endrule
   
   interface Put request;
      method Action put(MRequestUT m) if (state == STATE_READY);
         if(m matches tagged ReqOp .r) begin
            match { .opd1, .opd2 } = r;
            $display("%3d: PUT: %h %h %h", $time, acc, opd1, opd2);
            fpu_mult.request.put (tuple3(opd1, opd2, defaultValue));
            state <= STATE_LOCK;
            $display("%3d: STATE_LOCK", $time);
         end 
         else if(m matches tagged Init .a) begin
            $display("%3d: Init", $time);
            alloc_size <= extend(a);
            add_range <= (extend(a) >> 1);
            add_count <= 0;
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

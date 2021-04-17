package Main;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;


import RegFile :: *;
import Memory :: *;

import Vector :: *;
import FIFOF :: *;

import ZipReduceServer :: *;
import StmtFSM :: *;

typedef struct {
   UInt#(32) addr;
   UInt#(8) offset;
   UInt#(8) stride;
   UInt#(8) count;
} MatUnitPtr deriving (Eq, Bits);


typedef struct {
   MatUnitPtr ptr_a;
   MatUnitPtr ptr_b;
   MatUnitPtr ptr_c;
} MatUnitArgs deriving (Eq, Bits);

typedef enum {
   STATUS_LOAD,
   STATUS_OK
} MatUnitStatus deriving (Eq, Bits); 

(* synthesize *)
module mkMain(Empty);
   Integer alloc_size = 4;
   Integer numServers = 4;
   RegFile #(Bit #(32), FSingle) mem <- mkRegFileLoad ("array1.hex", 0, fromInteger(alloc_size) - 1);

   Server#(MRequestUT, FSingle) marr <- mkZipReduceServer;

   let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 1, count: 2};
   let ptr_b = MatUnitPtr{addr: 4, offset: 0, stride: 2, count: 2};
   let ptr_c = MatUnitPtr{addr: 8, offset: 0, stride: 1, count: 1};
   
   Reg#(UInt#(8)) i <- mkReg(0);

   FSM load_data <- mkFSM(seq
      for(i<=0; i < ptr_a.count; i<=i+1) seq
         action
            let a = mem.sub(extend(pack(i)));
            let b = mem.sub(fromInteger(alloc_size/2) + extend(pack(i)));
            marr.request.put(ReqOp(tuple2(a, b)));
            $display("%3d: Put: %h %h", $time, a, b);
         endaction
      endseq
      action
         marr.request.put(Execute);
         $display("%3d: Execute", $time);
      endaction
   endseq);

   Reg#(bit) b <- mkReg(0);
   rule rl_start_fsm (!unpack(b));
      $display("%3d: FSM Start", $time);
      load_data.start;
      b <= 1;
   endrule
   
   rule rl_out;
      FSingle out <- marr.response.get();
      $display("%3d: Output: %h", $time, out);
      $finish(0);
   endrule
   
endmodule
endpackage

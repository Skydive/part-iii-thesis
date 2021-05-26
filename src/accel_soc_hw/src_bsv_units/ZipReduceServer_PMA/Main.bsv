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

`ifndef ALLOC_SIZE
`define ALLOC_SIZE 256
`endif

(* synthesize *)
module mkMain(Empty);
   Integer alloc_size = `ALLOC_SIZE;
   //RegFile #(Bit #(32), FSingle) mem <- mkRegFile(0, fromInteger(alloc_size)-1);
   RegFile #(Bit #(32), FSingle) mem <- mkRegFileLoad ("array1.hex", 0, fromInteger(alloc_size) - 1);

   Server#(MRequestUT, FSingle) marr <- mkZipReduceServer;

   let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 1, count: fromInteger(alloc_size/2)};
   let ptr_b = MatUnitPtr{addr: fromInteger(alloc_size/2), offset: 0, stride: 1, count: fromInteger(alloc_size/2)};
   
   Reg#(UInt#(8)) i <- mkReg(0);

   function Bit#(32) get_mem_addr(MatUnitPtr ptr, UInt#(16) k);
      return pack(ptr.addr) + extend(pack(ptr.offset)) + extend(pack(ptr.stride)) * extend(pack(k));
   endfunction
   
   FSM load_data <- mkFSM(seq
      action
         marr.request.put(Init(extend(ptr_a.count)));
	 $display("%3d: Init Command Issued: %d", $time, ptr_a.count);
      endaction
      for(i<=0; i < ptr_a.count; i<=i+1) seq
         action
            let a = mem.sub(get_mem_addr(ptr_a, extend(i)));
            let b = mem.sub(fromInteger(alloc_size/2) + extend(pack(i)));
            marr.request.put(ReqOp(tuple2(a, b)));
         endaction
      endseq
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

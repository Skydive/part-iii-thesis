package Main;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;

import RegFile :: *;
import Vector :: *;

import MultiPortBRAM :: *;
import StmtFSM :: *;

(* synthesize *)
module mkMain(Empty);
   Integer alloc_size = 48;
   Integer bank_count = 4;
   //RegFile #(Bit #(32), FSingle) mem <- mkRegFile(0, fromInteger(alloc_size)-1);
   RegFile #(Bit #(32), FSingle) mem <- mkRegFileLoad ("array1.hex", 0, fromInteger(alloc_size) - 1);

   MultiPortBRAM#(Bit #(32), FSingle, 4) pmem <- mkMultiPortBRAM;
   
   Reg#(UInt#(8)) i <- mkReg(0);

   FSM load_data <- mkFSM(seq
      for(i<=0; i < fromInteger(alloc_size); i<=i+1) seq
         action
            let a = mem.sub(pack(extend(i)));
            pmem.upd(pack(extend(i)), a);
         endaction
      endseq
      for(i<=0; i < fromInteger(alloc_size); i<=i+fromInteger(bank_count)) par
         action
            pmem.upd(pack(extend(i)), 0);
            for(Integer j=0; j<bank_count; j=j+1) begin
               Bit#(32) bank = fromInteger(j);
               Bit#(32) idx = pack(extend(i))+fromInteger(j);
               // let mem_a = pmem.sub(bank, idx);
               // let mem_b = pmem.sub(bank, idx+1);
               // $display("%3d: %2d: %1d->%h:%h", $time, idx, bank, mem_a, mem_b);
               let mem_a = pmem.sub(bank, idx);
               let mem_b = pmem.sub(bank, idx+1);
               let mem_c = pmem.sub(bank, idx+2);
               let mem_d = pmem.sub(bank, idx+3);
               let mem_e = pmem.sub(bank, idx+4);
               let mem_f = pmem.sub(bank, idx+5);
               $display("%3d: %2d: %1d->%h:%h:%h:%h:%h:%h", $time, idx, bank, mem_a, mem_b, mem_c, mem_d, mem_e, mem_f);
            end
         endaction
      endpar
      for(i<=0; i < fromInteger(alloc_size); i<=i+fromInteger(bank_count)) par
         action
            pmem.upd(pack(extend(i)), 0);
            for(Integer j=0; j<bank_count; j=j+1) begin
               Bit#(32) bank = fromInteger(j);
               Bit#(32) idx = pack(extend(i))+fromInteger(j);
               let mem_a = pmem.sub(bank, idx);
               let mem_b = pmem.sub(bank, idx+1);
               $display("%3d: %2d: %1d->%h", $time, idx, bank, mem_a);
            end
         endaction
      endpar
      $finish(0);
   endseq);

   Reg#(bit) b <- mkReg(0);
   rule rl_start_fsm (!unpack(b));
      $display("%3d: FSM Start", $time);
      load_data.start;
      b <= 1;
   endrule
   
endmodule
endpackage

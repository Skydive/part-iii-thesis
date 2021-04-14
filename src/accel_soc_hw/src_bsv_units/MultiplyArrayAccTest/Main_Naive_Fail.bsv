package Main;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;


import RegFile :: *;
import Memory :: *;

import Vector :: *;
import FIFOF :: *;

import ZipReduceUnit :: *;
import List :: *;

typedef struct {
   Bit#(32) addr;
   Bit#(8) offset;
   Bit#(8) stride;
   Bit#(8) count;
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

   Vector#(4,Reg#(MatUnitStatus)) serv_status <- replicateM(mkReg(STATUS_OK));
   Vector#(4,Reg#(Bit#(32))) serv_count <- replicateM(mkReg(0));
   Vector#(4,Reg#(MatUnitArgs)) serv_args <- replicateM(mkReg(unpack(0)));
   Vector#(4,Reg#(Bit#(32))) serv_len <- replicateM(mkReg(0));
   Vector#(4,Server#(MRequestUT, FSingle)) servers <- replicateM(mkZipReduceUnit);

   Reg#(Bit#(32)) r_count <- mkReg(0);
   rule rl_start (r_count == 0);
      let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 1, count: 2};
      let ptr_b = MatUnitPtr{addr: 4, offset: 0, stride: 2, count: 2};
      let ptr_c = MatUnitPtr{addr: 8, offset: 0, stride: 1, count: 1};
      serv_args[0] <= MatUnitArgs{ptr_a:ptr_a, ptr_b:ptr_b, ptr_c:ptr_c};
      serv_status[0] <= STATUS_LOAD;
      r_count <= r_count + 1;
   endrule
   // rule rl_start2 (r_count == 1)
   //    let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 2, count: 2};
   //    let ptr_b = MatUnitPtr{addr: 4, offset: 1, stride: 2, count: 2};
   //    let ptr_c = MatUnitPtr{addr: 8, offset: 1, stride: 1, count: 1};
   //    serv_args[1] <= MatUnitArgs(ptr_a, ptr_b, ptr_c);
   //    serv_status[1] <= STATUS_LOAD;
   //    r_count <= r_count + 1;
   // endrule
   // rule rl_start3 (r_count == 1)
   //    let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 2, count: 2};
   //    let ptr_b = MatUnitPtr{addr: 4, offset: 1, stride: 2, count: 2};
   //    let ptr_c = MatUnitPtr{addr: 8, offset: 1, stride: 1, count: 1};
   //    serv_args[1] <= MatUnitArgs(ptr_a, ptr_b, ptr_c);
   //    serv_status[1] <= STATUS_LOAD;
   //    r_count <= r_count + 1;
   // endrule
   // rule rl_start4 (r_count == 1)
   //    let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 2, count: 2};
   //    let ptr_b = MatUnitPtr{addr: 4, offset: 1, stride: 2, count: 2};
   //    let ptr_c = MatUnitPtr{addr: 8, offset: 1, stride: 1, count: 1};
   //    serv_args[1] <= MatUnitArgs(ptr_a, ptr_b, ptr_c);
   //    serv_status[1] <= STATUS_LOAD;
   //    r_count <= r_count + 1;
   // endrule
   
   // rule rl_push(r_count < fromInteger(alloc_size/2));
   //    let a = arr_a.sub(r_count);
   //    let b = arr_a.sub(fromInteger(alloc_size/2) + r_count);
   //    $display("PUSH: ", r_count);
   //    marr.request.put(ReqOp(tuple2(a, b)));
   // endrule

   // rule rl_execute(r_count == fromInteger(alloc_size/2));
   //    marr.request.put(Execute);
   // endrule

   // rule rl_out;
   //    FSingle out <- marr.response.get();
   //    $display("OUT %h:", out);
   // endrule
   
   for(Integer j=0; j<numServers; j=j+1) begin
      rule rl_write_results (serv_status[j] == STATUS_LOAD);
         let result <- servers[j].response.get();
         let args = serv_args[j];
         let write_addr = args.ptr_c.addr + extend(args.ptr_c.offset);
         mem.upd(write_addr, result);
         serv_status[j] <= STATUS_OK;
         serv_count[j] <= 0;
         serv_args[j] <= unpack(0);
      endrule
      rule rl_load_results (serv_status[j] == STATUS_LOAD && serv_count[j] < serv_len[j]);
         let args = serv_args[j];
         let count = serv_count[j];
         let read_addr_a = args.ptr_a.addr + extend(args.ptr_a.offset) + extend(args.ptr_a.stride) * count;
         let read_addr_b = args.ptr_b.addr + extend(args.ptr_b.offset) + extend(args.ptr_b.stride) * count;
         servers[j].request.put(ReqOp(tuple2(mem.sub(read_addr_a), mem.sub(read_addr_b))));
         serv_count[j] <= serv_count[j] + 1;
      endrule
      rule rl_exec_results (serv_status[j] == STATUS_LOAD && serv_count[j] == serv_len[j]);
         servers[j].request.put(Execute);
      endrule
   end
endmodule
endpackage

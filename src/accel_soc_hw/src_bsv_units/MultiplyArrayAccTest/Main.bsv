package Main;

import GetPut :: *;
import ClientServer :: *;

import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;


import RegFile :: *;
import Memory :: *;

import Vector :: *;
import FIFOF :: *;

import ZipReduceUnitServer :: *;
import List :: *;
import ConfigReg :: *;

typedef struct {
   Bit#(32) addr;
   Bit#(8) offset;
   Bit#(8) stride;
} MatUnitPtr deriving (Eq, Bits);


typedef struct {
   Bit#(8) count;
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
   Integer alloc_size = 12;
   RegFile #(Bit #(32), FSingle) rf <- mkRegFileLoad ("array1.hex", 0, fromInteger(alloc_size) - 1);

   Integer numServers = 3;
   Vector#(3,Vector#(128, Reg#(FSingle))) server_mem_a <- replicateM(replicateM(mkReg(0)));
   Vector#(3,Vector#(128, Reg#(FSingle))) server_mem_b <- replicateM(replicateM(mkReg(0)));

   Vector#(3,ConfigReg#(Bit#(8))) server_state <- replicateM(mkConfigReg(0));
   Vector#(3,Reg#(Bit#(8))) server_cnt <- replicateM(mkReg(0));
   Vector#(3,Reg#(Bit#(8))) server_len <- replicateM(mkReg(0));
   Vector#(3,Reg#(Bit#(32))) server_out_addr <- replicateM(mkReg(0));
   Vector#(3,Reg#(FSingle)) server_result <- replicateM(mkReg(0));
   Vector#(3,Server#(MRequestUT, FSingle)) servers <- replicateM(mkZipReduceUnitServer);

   Reg#(Bit#(32)) count_val <- mkReg(0);

   FIFOF#(Tuple2#(Bit#(8), MatUnitArgs)) cmd_buf <- mkFIFOF;
   
   Reg#(Bit#(32)) cycles <- mkReg(0);
   rule cyc;
      cycles <= cycles + 1;
   endrule
   
   Reg#(Bit#(8)) write_server <- mkReg(0);
   Reg#(Bit#(4)) copy_state <- mkReg(0);
   Reg#(Bit#(8)) copy_cnt <- mkReg(0);
   Reg#(Bit#(8)) copy_len <- mkReg(0);
   rule rl_start1(!cmd_buf.notEmpty() && count_val == 0);
      let count = 2;
      let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 1};
      let ptr_b = MatUnitPtr{addr: 4, offset: 0, stride: 2};
      let ptr_c = MatUnitPtr{addr: 8, offset: 0, stride: 1};
      let args = MatUnitArgs{count:count, ptr_a:ptr_a, ptr_b:ptr_b, ptr_c:ptr_c};
      cmd_buf.enq(tuple2(0, args));
      $display("Enqueue 0!", cycles);
   endrule
   rule rl_start2(!cmd_buf.notEmpty() && count_val == 1);
      let count = 2;
      let ptr_a = MatUnitPtr{addr: 0, offset: 0, stride: 1};
      let ptr_b = MatUnitPtr{addr: 4, offset: 1, stride: 2};
      let ptr_c = MatUnitPtr{addr: 8, offset: 1, stride: 1};
      let args = MatUnitArgs{count:count, ptr_a:ptr_a, ptr_b:ptr_b, ptr_c:ptr_c};
      cmd_buf.enq(tuple2(1, args));
      $display("Enqueue 1!", cycles);
   endrule
   rule rl_start3(!cmd_buf.notEmpty() && count_val == 2);
      let count = 2;
      let ptr_a = MatUnitPtr{addr: 0, offset: 2, stride: 1};
      let ptr_b = MatUnitPtr{addr: 4, offset: 0, stride: 2};
      let ptr_c = MatUnitPtr{addr: 8, offset: 1, stride: 1};
      let args = MatUnitArgs{count:count, ptr_a:ptr_a, ptr_b:ptr_b, ptr_c:ptr_c};
      cmd_buf.enq(tuple2(2, args));
      $display("Enqueue 2!", cycles);
   endrule

   // Populate servers...
   // TODO: Check if server BUSY
   rule rl_copy_start (cmd_buf.notEmpty() && copy_state == 0);
      match { .id, .args } = cmd_buf.first();
      copy_len <= args.count;
      copy_cnt <= 0;
      write_server <= id;
      copy_state <= 1;
      $display("Copy Start: ", id, cycles);
   endrule
   rule rl_copy (cmd_buf.notEmpty() && server_state[write_server] == 0 && copy_state == 1 && copy_cnt < copy_len);
      match { .id, .args } = cmd_buf.first();
      let read_addr_a = args.ptr_a.addr + extend(args.ptr_a.offset) + extend(args.ptr_a.stride) * extend(copy_cnt);
      let read_addr_b = args.ptr_b.addr + extend(args.ptr_b.offset) + extend(args.ptr_b.stride) * extend(copy_cnt);
      
      server_mem_a[write_server][copy_cnt] <= rf.sub(read_addr_a);
      server_mem_b[write_server][copy_cnt] <= rf.sub(read_addr_b);
      copy_cnt <= copy_cnt + 1;
   endrule
   rule rl_copy_stop (cmd_buf.notEmpty() && server_state[write_server] == 0 && copy_state == 1 && copy_cnt == copy_len);
      match { .id, .args } = cmd_buf.first();
      cmd_buf.deq();
      let len = args.count;
      
      server_state[write_server] <= 1;
      server_len[write_server] <= len;
      server_cnt[write_server] <= 0;
      server_out_addr[write_server] <= args.ptr_c.addr;
      copy_len <= 0;
      copy_state <= 0;
      copy_cnt <= 0;
      $display("Copy Stop: Exec: ", id);
      count_val <= count_val + 1;
   endrule
   
   // Write to memory on completion...
   // TODO: Make wrapper object for ZipUnit+Memory
   for(Integer i=0; i<numServers; i=i+1) begin
      rule rl_load_mem(server_state[i] == 1 && server_cnt[i] < server_len[i]);
         servers[i].request.put(ReqOp(tuple2(server_mem_a[i][server_cnt[i]], server_mem_b[i][server_cnt[i]])));
         server_cnt[i] <= server_cnt[i] + 1;
      endrule
      rule rl_exec_mem(server_state[i] == 1 && server_cnt[i] == server_len[i]);
         servers[i].request.put(Execute);
         server_cnt[i] <= 0;
         server_state[i] <= 2;
      endrule
      rule rl_write_res_mem(server_state[i] == 2);
         let result <- servers[i].response.get();
         $display("Result!?");
         server_result[i] <= result;
         server_state[i] <= 3;
      endrule
   end

   // Round robin
   Reg#(Bit#(8)) cur_out <- mkReg(0);
   for(Integer i=0; i<numServers; i=i+1) begin
      rule rl_move_cnt(cur_out == fromInteger(i));
         let next = cur_out + 1;
         cur_out <= (next>=fromInteger(numServers)) ? 0 : next;
      endrule
      rule rl_write_rf(cur_out == fromInteger(i) && server_state[i] == 3);
         let write_addr = server_out_addr[i];
         let result = server_result[i];
         rf.upd(write_addr, result);
         $display("Out: ", write_addr, result, cycles);
         server_state[i] <= 0;
      endrule
   end
endmodule
endpackage

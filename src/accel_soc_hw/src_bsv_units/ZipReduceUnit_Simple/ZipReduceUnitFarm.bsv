package ZipReduceUnitFarm;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;

import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;

import RegFile :: *;
import Memory :: *;

import GetPut::*;
import ClientServer::*;
import Connectable::*;
import List::*;
import Assert::*;

import ZipReduceUnit::*;

typedef struct {
   Bit#(32) addr;
   Bit#(8) offset;
   Bit#(8) stride;
   } MatUnitPtr;
typedef struct {
   MatUnitPtr ptr_a;
   MatUnitPtr ptr_b;
   MatUnitPtr ptr_c;
   } MatUnitArgs;

interface ZipReduceUnitFarm_IFC;
   method ActionValue#(Bool) check_free;
endinterface;

module mkZipReduceUnitFarm#(Integer numServers)(ZipReduceUnitFarm_IFC);
   RegFile #(Bit #(32), FSingle) mem <- mkRegFileLoad ("array1.hex", 0, 255);

   staticAssert(numServers > 1, "ServerFarm: number of servers must be > 1.");
   staticAssert(numServers < 65, "ServerFarm: number of servers must be < 65.");

   List#(Tuple2#(Reg#(MatUnitArgs), Server#(requestT,responseT))) servers <- replicateM(numServers, mkZipReduceUnit);
   Reg#(UInt#(6)) write_server <- mkReg(0);
   Reg#(UInt#(6)) read_server  <- mkReg(0);
   FIFOF#(requestT)  request_fifo  <- mkBypassFIFOF;
   FIFOF#(responseT) response_fifo <- mkBypassFIFOF;

   function Bit#(8) get_first_occupancy();
      let first_occupancy = 256;
      for(Integer i=256; i>=0; i--)
        if(!occupancy_bits[i])
           first_occupancy = i;
      end
      return first_occupancy;
   endfunction

   for(Integer j=0; j<numServers; j=j+1) begin
      rule rl_write_results;
         match { .args, .result } <- servers[j].response.get();
         let write_addr = args.ptr_c.addr + extend(args.ptr_c.offset)
         mem.upd(write_addr, result);
      endrule
   end

   rule rl_read_cmd;
      
   endrule

   interface Put request = toPut(request_fifo);
   interface Get response = toGet(response_fifo);

endmodule

endpackage

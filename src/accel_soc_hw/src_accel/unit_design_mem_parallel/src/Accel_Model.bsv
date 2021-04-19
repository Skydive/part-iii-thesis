
package Accel_Model;

export Accel_IFC(..), mkAccel;

// ================================================================
// BSV library imports

import  Vector       :: *;
import  FIFOF        :: *;
import  SpecialFIFOs :: *;
import  GetPut       :: *;
import  ClientServer :: *;
import  Memory       :: *;
import  ConfigReg    :: *;

// ----------------
// BSV additional libs

import Cur_Cycle  :: *;
import GetPut_Aux :: *;
import Semi_FIFOF :: *;
import ByteLane   :: *;

// ================================================================
// Project imports

import Fabric_Defs :: *;
import SoC_Map     :: *;
import AXI4_Types  :: *;


import FloatingPoint :: *;
typedef FloatingPoint#(8,23) FSingle;

import MultiPortBRAM :: *;
import ZipReduceServer :: *;

import Endianness :: *;


// 256 bits control register
Bit #(16) addr_TEST_control = 0;
Bit #(16) addr_TEST_command = 32*4;
Bit #(16) addr_TEST_data = 64*4;


Bit #(16) offset_con_occu = 1;

// ================================================================
// Interface

interface Accel_IFC;
   // Reset
   interface Server #(Bit #(0), Bit #(0)) server_reset;

   // set_addr_map should be called after this module's reset
   method Action set_addr_map (Fabric_Addr addr_base, Fabric_Addr addr_lim);

   // Main Fabric Reqs/Rsps
   interface AXI4_Slave_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave;
endinterface

// Local types and constants

typedef enum {STATE_START,
   STATE_READY
   } Module_State
deriving (Bits, Eq, FShow);

Integer address_stride = 4;

// ----------------------------------------------------------------
// ACCEL INTERNALS

typedef struct {
   LittleEndian#(Bit#(32)) addr;
   LittleEndian#(Bit#(8)) offset;
   LittleEndian#(Bit#(8)) stride;
   } MatUnitPtr deriving (Eq, Bits, FShow);

typedef struct {
   LittleEndian#(Bit#(8)) unit;
   LittleEndian#(Bit#(8)) count;
   MatUnitPtr ptr_a;
   MatUnitPtr ptr_b;
   MatUnitPtr ptr_c;
} MatUnitArgs deriving (Eq, Bits, FShow);

typedef enum {
              STATUS_LOAD,
              STATUS_OK
   } MatUnitStatus deriving (Eq, Bits);


// ----------------------------------------------------------------





// ----------------------------------------------------------------
// Split a bus address into (offset, lsbs), based on the address
// stride.

function Tuple2 #(Bit #(64), Bit #(3)) split_addr (Bit #(64) addr);
   Bit #(64) offset = ((address_stride == 4) ? (addr >> 2)           : (addr >> 3));
   Bit #(3)  lsbs   = ((address_stride == 4) ? { 1'b0, addr [1:0] }  : addr [2:0]);

   return tuple2 (offset, lsbs);
endfunction

// ----------------------------------------------------------------
// Extract data from AXI4 byte lanes, based on the AXI4 'strobe'
// (byte-enable) bits.

function Bit #(64) fn_extract_AXI4_data (Bit #(64) data, Bit #(8) strb);
   Bit #(64) result = 0;
   case (strb)
      8'b_0000_0001: result = zeroExtend (data [ 7:0]);
      8'b_0000_0010: result = zeroExtend (data [15:8]);
      8'b_0000_0100: result = zeroExtend (data [23:16]);
      8'b_0000_1000: result = zeroExtend (data [31:24]);
      8'b_0001_0000: result = zeroExtend (data [39:32]);
      8'b_0010_0000: result = zeroExtend (data [47:40]);
      8'b_0100_0000: result = zeroExtend (data [55:48]);
      8'b_1000_0000: result = zeroExtend (data [63:56]);

      8'b_0000_0011: result = zeroExtend (data [15:0]);
      8'b_0000_1100: result = zeroExtend (data [31:16]);
      8'b_0011_0000: result = zeroExtend (data [47:32]);
      8'b_1100_0000: result = zeroExtend (data [63:48]);

      8'b_0000_1111: result = zeroExtend (data [31:0]);
      8'b_1111_0000: result = zeroExtend (data [63:32]);

      8'b_1111_1111: result = zeroExtend (data [63:0]);
   endcase
   return result;
endfunction

(* synthesize *)
module mkAccel(Accel_IFC);
   
   Integer verbosity = 0;
   Reg #(Module_State) rg_state <- mkReg(STATE_START);

   Vector #(32,  Reg #(Bit #(8))) rgv_control <- replicateM(mkConfigReg(0));
   Vector #(32,  Reg #(Bit #(8))) rgv_command <- replicateM(mkReg(0));
   //Vector #(256, Reg #(Bit #(8))) rgv_data <- replicateM(mkReg(0));
   MultiPortBRAM#(Bit#(16), FSingle, 5) rgv_data <- mkMultiPortBRAM;

   // These regs represent where this UART is placed in the address space.
   Reg #(Fabric_Addr)  rg_addr_base <- mkRegU;
   Reg #(Fabric_Addr)  rg_addr_lim  <- mkRegU;

   Reg #(Fabric_Addr) rg_addr_control <- mkRegU;
   Reg #(Fabric_Addr) rg_addr_command <- mkRegU;
   Reg #(Fabric_Addr) rg_addr_data <- mkRegU;

   FIFOF #(Bit #(0)) f_reset_reqs <- mkFIFOF;
   FIFOF #(Bit #(0)) f_reset_rsps <- mkFIFOF;

   // Connector to AXI4 fabric
   AXI4_Slave_Xactor_IFC #(Wd_Id, Wd_Addr, Wd_Data, Wd_User) slave_xactor <- mkAXI4_Slave_Xactor;

   rule rl_reset;
      f_reset_reqs.deq;

      for (Integer i=0; i<32; i=i+1)
         rgv_control[i] <= 0;
      //for (Integer i=0; i<64; i=i+1)
      //   rgv_data[i] <= 0;

      slave_xactor.reset;

      rg_state <= STATE_READY;

      f_reset_rsps.enq(?);
   endrule

   rule rl_process_rd_req (rg_state == STATE_READY);
      let rda <- pop_o (slave_xactor.o_rd_addr);

      let byte_addr = rda.araddr - rg_addr_base;
      match { .offset, .lsbs } = split_addr (zeroExtend (byte_addr));
      
      Fabric_Data rdata = 0;
      AXI4_Resp rresp      = axi4_resp_okay;

      if ((rda.araddr < rg_addr_base) || (rda.araddr >= rg_addr_lim)) begin
	       $display ("%0d: %m.rl_process_rd_req: ERROR: ACCEL addr out of bounds", cur_cycle);
	       $display ("    UART base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	       $display ("    AXI4 request: ", fshow (rda));
	       rresp = axi4_resp_decerr;
      end
      else if (lsbs != 0) begin
	       $display ("%0d: %m.rl_process_rd_req: ERROR: ACCEL misaligned addr", cur_cycle);
	       $display ("    ", fshow (rda));
	       rresp = axi4_resp_slverr;
      end
      // offset 0: CONTROL
      else if (byte_addr >= zeroExtend(addr_TEST_control) && byte_addr < zeroExtend(addr_TEST_command)) begin
         let rgv_idx = (rda.araddr - rg_addr_control);
         let rgv = rgv_control;
         rdata = zeroExtend({rgv[rgv_idx+3], rgv[rgv_idx+2], rgv[rgv_idx+1], rgv[rgv_idx]});
      end
      else if (byte_addr >= zeroExtend(addr_TEST_command) && byte_addr < zeroExtend(addr_TEST_data)) begin
         let rgv_idx = (rda.araddr - rg_addr_command);
         let rgv = rgv_command;
         rdata = zeroExtend({rgv[rgv_idx+3], rgv[rgv_idx+2], rgv[rgv_idx+1], rgv[rgv_idx]});
         // $display("READ CMD BASE ADDR: %h", rg_addr_command);
      end
      else if (byte_addr >= zeroExtend(addr_TEST_data)) begin
         if (byte_addr[1:0] != 0) begin
         	  $display ("%0d: %m.rl_process_rd_req: ERROR: ACCEL misaligned addr", cur_cycle);
	          $display ("    ", fshow (rda));
	          rresp = axi4_resp_slverr;
         end
         else begin
            let rgv_idx = truncate((rda.araddr - rg_addr_data) >> 2);
            FSingle fdata <- rgv_data.sub(0, rgv_idx);
            rdata = zeroExtend(pack(fdata));
         end
      end
      else begin
	       $display ("%0d: %m.rl_process_rd_req: ERROR: ACCEL unsupported addr", cur_cycle);
	       $display ("    ", fshow (rda));
	       rresp = axi4_resp_decerr;
      end
      
      // $display("READ ACCEL: %h %h %h", rda.araddr, byte_addr, addr_TEST_command);

      if ((valueOf (Wd_Data) == 64) && (byte_addr [2:0] == 3'b100))
	       rdata = rdata << 32;

      // $display("READ ACCEL: %h -> %h", byte_addr, rdata);

      let rdr = AXI4_Rd_Data {rid:   rda.arid,
			                        rdata: rdata,
			                        rresp: rresp,
			                        rlast: True,
			                        ruser: rda.aruser};
      slave_xactor.i_rd_data.enq (rdr);
   endrule

   rule rl_process_wr_req (rg_state == STATE_READY);
      let wra <- pop_o (slave_xactor.o_wr_addr);
      let wrd <- pop_o (slave_xactor.o_wr_data);

      Bit #(64) wdata     = zeroExtend (wrd.wdata);
      Bit #(8)  wstrb     = zeroExtend (wrd.wstrb);
      Bit #(8)  data_byte = truncate (fn_extract_AXI4_data (wdata, wstrb));
      
      // $display("DEBUG WRITE!: wdata: ", fshow(wdata));
      // $display("DEBUG WRITE!: wstrb: ", fshow(wstrb));

      let byte_addr = wra.awaddr - rg_addr_base;
      match { .offset, .lsbs } = split_addr (zeroExtend (byte_addr));

      Fabric_Data rdata = 0;
      AXI4_Resp bresp      = axi4_resp_okay;

      if ((wra.awaddr < rg_addr_base) || (wra.awaddr >= rg_addr_lim)) begin
	       $display ("%0d: %m.rl_process_wr_req: ERROR: ACCEL addr out of bounds", cur_cycle);
	       $display ("    UART base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	       $display ("    AXI4 request: ", fshow (wra));
	       bresp = axi4_resp_decerr;
      end
      else if (lsbs != 0) begin
	       $display ("%0d: %m.rl_process_wr_req: ERROR: ACCEL misaligned addr", cur_cycle);
	       $display ("    ", fshow (wra));
	       bresp = axi4_resp_slverr;
      end
      // offset 0: CONTROL
      else if (byte_addr >= zeroExtend(addr_TEST_control) && byte_addr < zeroExtend(addr_TEST_command)) begin
         let rgv_idx = (wra.awaddr - rg_addr_control);
         if((valueOf (Wd_Data) == 64) && byte_addr[2:0] == 3'b100) begin
            wdata = wdata >> 32;
            wstrb = wstrb >> 4;
         end
         for(Integer i=0; i<4; i=i+1)
            if(wstrb[i] != 0)
               rgv_control[rgv_idx+fromInteger(i)] <= wdata[8*i+7:8*i];
      end
      else if (byte_addr >= zeroExtend(addr_TEST_command) && byte_addr < zeroExtend(addr_TEST_data)) begin
         let rgv_idx = (wra.awaddr - rg_addr_command);
         if((valueOf (Wd_Data) == 64) && byte_addr[2:0] == 3'b100) begin
            wdata = wdata >> 32;
            wstrb = wstrb >> 4;
         end
         for(Integer i=0; i<4; i=i+1)
            if(wstrb[i] != 0)
               rgv_command[rgv_idx+fromInteger(i)] <= wdata[8*i+7:8*i];
      end
      else begin
      // offset 1: DATA
         if((valueOf (Wd_Data) == 64) && byte_addr[2:0] == 3'b100) begin
            wdata = wdata >> 32;
            wstrb = wstrb >> 4;
         end
         if(wstrb != 8'hFF && wstrb != 8'h0F) begin
         	  $display ("%0d: %m.rl_process_wr_req: ERROR: ACCEL bad strobe", cur_cycle);
	          $display ("    ", fshow (wra));
	          $display ("    ", fshow (wrd));
	          bresp = axi4_resp_slverr;
         end
         else if (byte_addr[1:0] != 0) begin
            $display ("%0d: %m.rl_process_wr_req: ERROR: ACCEL misaligned float addr", cur_cycle);
	          $display ("    ", fshow (wra));
	          bresp = axi4_resp_slverr;
         end
         else begin
            // TODO: Stall if internal write!?
            // TODO: Or fake software backpressure!?
            let rgv_idx = truncate((wra.awaddr - rg_addr_data) >> 2);
            rgv_data.upd(rgv_idx, unpack(truncate(wdata)));
         end
      end
      
      // else begin
	    //    $display ("%0d: %m.rl_process_wr_req: ERROR: TEST unsupported addr", cur_cycle);
	    //    $display ("    ", fshow (wra));
	    //    $display ("    ", fshow (wrd));
	    //    bresp = axi4_resp_decerr;
      // end

      // Send write-response to bus
      let wrr = AXI4_Wr_Resp {bid: wra.awid,
                           bresp: bresp,
                           buser: wra.awuser};
      slave_xactor.i_wr_resp.enq (wrr);
   endrule
   
   
   // Some stupid stuff
   function Bool control_is_exec();
      return unpack(rgv_control[0][0]);
   endfunction
   function Bool control_is_busy();
      return unpack(rgv_control[0][1]);
   endfunction

   FIFOF#(MatUnitArgs) cmd_buf <- mkBypassFIFOF;
   Vector#(4,Server#(MRequestUT, FSingle)) servers <- replicateM(mkZipReduceServer);
   Vector#(4, Reg#(MatUnitArgs)) server_cmd <- replicateM(mkReg(unpack(0)));
   Vector#(4, Reg#(Bool)) server_busy <- replicateM(mkReg(False));
   Vector#(4, Reg#(Bit#(8))) server_count <- replicateM(mkReg(0));
   Vector#(4, Reg#(Bool)) server_done <- replicateM(mkReg(False));
   Vector#(4, Reg#(FSingle)) server_result <- replicateM(mkReg(0));

   // TODO: somehow make use of Connectables!?
   
   rule rl_decode_command (rg_state == STATE_READY && control_is_exec() && !control_is_busy());
      rgv_control[0][1:0] <= 2'b10;
      Bit#(160) command = 0;
      Vector#(20, Bit#(8)) cmd_vec;
      for(Integer i=0; i<20; i=i+1)
         cmd_vec[i] = rgv_command[i];
      command = pack(reverse(cmd_vec)); // Swap byte order
      // TODO: Decode single command
      MatUnitArgs args = unpack(truncate(command)); // Reverse endian-ness
      $display("ENQ command: ", fshow(unpackle(args.ptr_a.addr)));
      $display("COMMAND: %h", pack(args));
      cmd_buf.enq(args);
   endrule

   rule rl_exec_command (cmd_buf.notEmpty());
      MatUnitArgs args = cmd_buf.first;
      let unit_id = unpackle(args.unit);
      let count = unpackle(args.count);
      if(server_busy[unit_id] == False) begin
         cmd_buf.deq;
         server_busy[unit_id] <= True;
         server_cmd[unit_id] <= args;
         server_count[unit_id] <= 0;
         servers[unit_id].request.put(tagged Init unpack(extend(count)));
         rgv_control[0][1:0] <= 2'b00;
      end
   endrule
   
   for(Integer i=0; i<4; i=i+1) begin
      rule rl_load_mem(server_busy[i] == True);
         let args = server_cmd[i];
         let len = unpackle(args.count);
         let count = server_count[i];
         //$display("%3d: %d %d %d", $time, i, count, len);
         if(count < len) begin
            // $display("ADDR A: 0x%h", unpackle(args.ptr_a.addr));
            // $display("ADDR B: 0x%h", unpackle(args.ptr_b.addr));
            // TODO: make function for this
            let read_addr_a = ((unpackle(args.ptr_a.addr)+4*extend(unpackle(args.ptr_a.offset))+4*extend(unpackle(args.ptr_a.stride))*extend(count)) - truncate(pack(rg_addr_data)))>>2;
            let read_addr_b = ((unpackle(args.ptr_b.addr)+4*extend(unpackle(args.ptr_b.offset))+4*extend(unpackle(args.ptr_b.stride))*extend(count)) - truncate(pack(rg_addr_data)))>>2;
            let a <- rgv_data.sub(fromInteger(i)+1, truncate(read_addr_a));
            let b <- rgv_data.sub(fromInteger(i)+1, truncate(read_addr_b));
            servers[i].request.put(tagged ReqOp tuple2(a, b));
            server_count[i] <= server_count[i] + 1;
         end
      endrule
      rule rl_write_res_mem(server_busy[i] == True && server_done[i] == False);
         let result <- servers[i].response.get();
         server_result[i] <= result;
         server_done[i] <= True;
      endrule
   end
   
   rule rl_write_res;
      Vector#(4, Bool) sd = replicate(False);
      for(Integer i=0; i<4; i=i+1)
         sd[i] = server_done[i];
      let f = findIndex(id, sd);
      if(f matches tagged Valid .idx) begin
         let data = server_result[idx];
         let args = server_cmd[idx];
         let addr = (unpackle(args.ptr_c.addr) - truncate(pack(rg_addr_data))) >> 2;
         rgv_data.upd(truncate(addr), data);
         $display("WRITE: %h", data);
         server_done[idx] <= False;
         server_busy[idx] <= False;
      end
   endrule
   rule rl_busy_map;
      Vector#(4, Bool) sb = replicate(False);
      for(Integer i=0; i<4; i=i+1)
         sb[i] = server_busy[i];
      Bit#(4) busy_bits = pack(sb);
      rgv_control[1] <= extend(busy_bits);
   endrule

   interface server_reset   = toGPServer (f_reset_reqs, f_reset_rsps);
   
   method Action  set_addr_map (Fabric_Addr addr_base, Fabric_Addr addr_lim);
      if (addr_base [2:0] != 0)
	       $display ("%0d: WARNING: ACCEL.set_addr_map: addr_base 0x%0h is not 8-Byte-aligned",
		           cur_cycle, addr_base);

      if (addr_lim [2:0] != 0)
	       $display ("%0d: WARNING: ACCEL.set_addr_map: addr_lim 0x%0h is not 8-Byte-aligned",
		           cur_cycle, addr_lim);

      rg_addr_base <= addr_base;
      rg_addr_lim  <= addr_lim;

      rg_addr_control <= addr_base + zeroExtend(addr_TEST_control);
      rg_addr_command <= addr_base + zeroExtend(addr_TEST_command);
      rg_addr_data <= addr_base + zeroExtend(addr_TEST_data);
      $display ("%0d: ACCEL.set_addr_map: addr_base 0x%0h addr_lim 0x%0h",
            cur_cycle, addr_base, addr_lim);
   endmethod

   interface slave = slave_xactor.axi_side;
endmodule

endpackage

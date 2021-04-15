
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
import ZipReduceServer :: *;

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
                Bit#(32) addr;
                Bit#(8) offset;
                Bit#(8) stride;
   } MatUnitPtr deriving (Eq, Bits, FShow);

typedef struct {
                Bit#(16) count;
                MatUnitPtr ptr_a;
                MatUnitPtr ptr_b;
                MatUnitPtr ptr_c;
   } MatUnitArgs deriving (Eq, Bits, FShow);

typedef enum {
              STATUS_LOAD,
              STATUS_OK
   } MatUnitStatus deriving (Eq, Bits);

function Bit#(n) endianSwap(Bit#(n) i) provisos (Mul#(nbytes,8,n),Div#(n,8,nbytes),Log#(nbytes,k));
   Vector#(nbytes,Bit#(8)) t = toChunks(i);
   return pack(reverse(t));
endfunction


// function MatUnitArgs MatUnitArgs_endianSwap(MatUnitArgs x);
//    MatUnitArgs out = unpack(pack(x));
//    out.count = endianSwap(x.count);
//    out.ptr_a.addr = endianSwap(x.ptr_a.addr);
//    out.ptr_b.addr = endianSwap(x.ptr_b.addr);
//    out.ptr_c.addr = endianSwap(x.ptr_c.addr);
//    return out;
// endfunction


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

   Vector #(32,  Reg #(Bit #(8))) rgv_control <- replicateM(mkReg(0));
   Vector #(32,  Reg #(Bit #(8))) rgv_command <- replicateM(mkReg(0));
   Vector #(256, Reg #(Bit #(8))) rgv_data <- replicateM(mkReg(0));

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
	       $display ("%0d: %m.rl_process_rd_req: ERROR: TEST addr out of bounds", cur_cycle);
	       $display ("    UART base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	       $display ("    AXI4 request: ", fshow (rda));
	       rresp = axi4_resp_decerr;
      end
      else if (lsbs != 0) begin
	       $display ("%0d: %m.rl_process_rd_req: ERROR: TEST misaligned addr", cur_cycle);
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
      // offset 1: DAT
         let rgv_idx = (rda.araddr - rg_addr_data);
         let rgv = rgv_data;
         rdata = zeroExtend({rgv[rgv_idx+3], rgv[rgv_idx+2], rgv[rgv_idx+1], rgv[rgv_idx]});
      end
      else begin
	       $display ("%0d: %m.rl_process_rd_req: ERROR: TEST unsupported addr", cur_cycle);
	       $display ("    ", fshow (rda));
	       rresp = axi4_resp_decerr;
      end
      
      $display("READ ACCEL: %h %h %h", rda.araddr, byte_addr, addr_TEST_command);

      if ((valueOf (Wd_Data) == 64) && (byte_addr [2:0] == 3'b100))
	       rdata = rdata << 32;

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
      
      $display("DEBUG WRITE!: wdata: ", fshow(wdata));
      $display("DEBUG WRITE!: wstrb: ", fshow(wstrb));

      let byte_addr = wra.awaddr - rg_addr_base;
      match { .offset, .lsbs } = split_addr (zeroExtend (byte_addr));

      Fabric_Data rdata = 0;
      AXI4_Resp bresp      = axi4_resp_okay;

      if ((wra.awaddr < rg_addr_base) || (wra.awaddr >= rg_addr_lim)) begin
	       $display ("%0d: %m.rl_process_wr_req: ERROR: TEST addr out of bounds", cur_cycle);
	       $display ("    UART base addr 0x%0h  limit addr 0x%0h", rg_addr_base, rg_addr_lim);
	       $display ("    AXI4 request: ", fshow (wra));
	       bresp = axi4_resp_decerr;
      end
      else if (lsbs != 0) begin
	       $display ("%0d: %m.rl_process_wr_req: ERROR: TEST misaligned addr", cur_cycle);
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
         let rgv_idx = (wra.awaddr - rg_addr_data);
         if((valueOf (Wd_Data) == 64) && byte_addr[2:0] == 3'b100) begin
            wdata = wdata >> 32;
            wstrb = wstrb >> 4;
         end
         for(Integer i=0; i<4; i=i+1)
            if(wstrb[i] != 0)
               rgv_data[rgv_idx+fromInteger(i)] <= wdata[8*i+7:8*i];
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
   
   // rule rl_perform_accel (rg_state == STATE_READY && rg_control[0] == 1);
   //    for(Integer i=0; i<64; i=i+1) begin
   //       Bit #(32) data = {rgv_data[4*i+3], rgv_data[4*i+2], rgv_data[4*i+1], rgv_data[4*i]};
   //       data = data*2;
   //       for(Integer j=0; j<4; j=j+1) begin
   //          rgv_data[4*i+j] <= data[8*j+7:8*j];
   //          //$display("WRITTEN: ", 4*i+j);
   //       end
   //    end
   //    rg_control <= {rg_control[7:2], 'b10};
   // endrule
   
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

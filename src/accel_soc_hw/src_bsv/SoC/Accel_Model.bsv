
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
      
      // $display("READ ACCEL: %h %h %h", rda.araddr, byte_addr, addr_TEST_command);

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
         //$display("DEBUG WRITE!: wdata: ", fshow(wdata));
         //$display("DEBUG WRITE!: wstrb: ", fshow(wstrb));
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

      
   
   
   // Accelerator stuff!?
   function Bool control_is_exec();
      return unpack(rgv_control[0][0]);
   endfunction
   function Bool control_is_busy();
      return unpack(rgv_control[0][1]);
   endfunction
   
   // TODO: Decoder combinatorial logic...

   FIFOF#(Tuple2#(Bit#(16), MatUnitArgs)) cmd_buf <- mkFIFOF;
   Integer numServers = 3;
   Vector#(3,Vector#(128, Reg#(FSingle))) server_mem_a <- replicateM(replicateM(mkReg(0)));
   Vector#(3,Vector#(128, Reg#(FSingle))) server_mem_b <- replicateM(replicateM(mkReg(0)));

   Vector#(3,ConfigReg#(Bit#(8))) server_state <- replicateM(mkConfigReg(0));
   Vector#(3,Reg#(Bit#(16))) server_cnt <- replicateM(mkReg(0));
   Vector#(3,Reg#(Bit#(16))) server_len <- replicateM(mkReg(0));
   Vector#(3,Reg#(Bit#(32))) server_out_addr <- replicateM(mkReg(0));
   Vector#(3,Reg#(FSingle)) server_result <- replicateM(mkReg(0));
   Vector#(3,Server#(MRequestUT, FSingle)) servers <- replicateM(mkZipReduceServer);

   rule rl_decode_command (rg_state == STATE_READY && control_is_exec() && !control_is_busy());
      rgv_control[0][1:0] <= 2'b10;
      Bit#(160) command = 0;
      Vector#(20, Bit#(8)) cmd_vec;
      for(Integer i=0; i<20; i=i+1)
         cmd_vec[i] = rgv_command[i];
      command = pack(reverse(cmd_vec)); // Swap byte order
      // TODO: Decode single command
      MatUnitArgs args = unpack(truncate(command)); // Reverse endian-ness
      args.count = endianSwap(args.count);
      args.ptr_a.addr = endianSwap(args.ptr_a.addr);
      args.ptr_b.addr = endianSwap(args.ptr_b.addr);
      args.ptr_c.addr = endianSwap(args.ptr_c.addr);
      $display("ENQ command: ", fshow(args));
      $display("COMMAND: %h", pack(args));
      cmd_buf.enq(tuple2(0, args));
   endrule
   
   // TODO: issue command
   // TODO: unset busy on issue
   
   Reg#(Bit#(16)) write_server <- mkReg(0);
   Reg#(Bit#(4)) copy_state <- mkReg(0);
   Reg#(Bit#(16)) copy_cnt <- mkReg(0);
   Reg#(Bit#(16)) copy_len <- mkReg(0);

   
      // Populate servers...
   // TODO: Check if server BUSY
   rule rl_copy_start (cmd_buf.notEmpty() && copy_state == 0);
      let x = cmd_buf.first();
      match { .id, .args } = x;
      copy_len <= args.count;
      copy_cnt <= 0;
      write_server <= id;
      copy_state <= 1;
      $display("Copy Start: ", id);
   endrule
   rule rl_copy (cmd_buf.notEmpty() && server_state[write_server] == 0 && copy_state == 1 && copy_cnt < copy_len);
      match { .id, .args } = cmd_buf.first();
      let read_addr_a = args.ptr_a.addr + 4*extend(args.ptr_a.offset) + 4*extend(args.ptr_a.stride) * extend(copy_cnt) - truncate(pack(rg_addr_data));
      let read_addr_b = args.ptr_b.addr + 4*extend(args.ptr_b.offset) + 4*extend(args.ptr_b.stride) * extend(copy_cnt) - truncate(pack(rg_addr_data));
      
      $display("read_addr_a: %h", read_addr_a);
      $display("read_addr_b: %h", read_addr_b);
      Bit#(32) a = 0;
      Bit#(32) b = 0;
      for(Integer i=0; i<4; i=i+1) begin
         a[i*8+7:i*8] = rgv_data[read_addr_a+fromInteger(i)];
         b[i*8+7:i*8] = rgv_data[read_addr_b+fromInteger(i)];
      end
      
      server_mem_a[write_server][copy_cnt] <= unpack(a);
      server_mem_b[write_server][copy_cnt] <= unpack(b);
      copy_cnt <= copy_cnt + 1;
   endrule
   rule rl_copy_stop (cmd_buf.notEmpty() && server_state[write_server] == 0 && copy_state == 1 && copy_cnt == copy_len);
      match { .id, .args } = cmd_buf.first();
      cmd_buf.deq();
      let len = args.count;
      
      server_state[write_server] <= 1;
      server_len[write_server] <= len;
      server_cnt[write_server] <= 0;
      server_out_addr[write_server] <= args.ptr_c.addr - truncate(pack(rg_addr_data));
      
      copy_len <= 0;
      copy_state <= 0;
      copy_cnt <= 0;
      $display("Copy Stop: Exec: ", id);
      // count_val <= count_val + 1;
      // END BUSY:
      rgv_control[0][1:0] <= 2'b00;
      // Control occupancy bit
      rgv_control[1] <= rgv_control[1] | (1 << write_server);
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
         for(Integer j=0; j<4; j=j+1)
            rgv_data[write_addr+fromInteger(j)] <= pack(result)[8*j+7:8*j];
         $display("Out: %h %h", write_addr, result);
         server_state[i] <= 0;
      endrule
   end

   
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

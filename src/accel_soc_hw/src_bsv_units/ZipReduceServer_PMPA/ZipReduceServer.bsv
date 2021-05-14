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
   STATE_MULT,
   STATE_ADD,
   STATE_REM,
   STATE_COMPLETE
   } AccState deriving (Bits, Eq);


typedef union tagged {
   UInt#(16) Init;
   Tuple2#(FSingle, FSingle) ReqOp;
   } MRequestUT deriving (Eq, Bits);


Integer max_alloc_size = 32;

(* synthesize *)
module mkZipReduceServer(Server#(MRequestUT, FSingle));
   Reg#(UInt#(16)) m_count <- mkReg(0);
   ConfigReg#(AccState) state <- mkConfigReg(STATE_READY);

   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR ) fpu_mult <- mkFloatingPointMultiplier;
   Server# (Tuple3# (FSingle, FSingle, RoundMode)
            , FpuR ) fpu_add <- mkFloatingPointAdder;

   ConfigReg#(FSingle) acc <- mkConfigReg(0.0);
   Reg#(UInt#(16)) alloc_size <- mkReg(0);

   RegFile#(UInt#(16), FSingle) buffer <- mkRegFile(0, 128-1);
   RegFile#(UInt#(8),  FSingle) rem_buf <- mkRegFile(0, 32);
   Reg#(UInt#(8)) rem_count <- mkReg(0);
   
   // Rule, do multiply
   rule rl_pipe_response_mult ((state == STATE_READY || state == STATE_MULT) && m_count < alloc_size);
      match { .res, .exc } <- fpu_mult.response.get();
      if(m_count == alloc_size-1) begin
         state <= STATE_ADD;
      end
      buffer.upd(m_count, res);
      m_count <= m_count + 1;
      $display("%3d:%2d: Mul Result: %h", $time, m_count, pack(res));
   endrule
   
   // Rule, pairwise add & reduce
   Reg#(UInt#(16)) a_count <- mkReg(0);
   Reg#(Bool) a_free <- mkReg(True);
   Reg#(Bool) rem_free <- mkReg(False);

   rule rl_pairwise_add_req(state == STATE_ADD && a_free && a_count + 2 <= m_count && m_count != 1);
      if(m_count % 2 == 1) begin
         $display("%3d:  :%2d REMAINDER", $time, m_count);
         m_count <= m_count - 1;
         let rem = buffer.sub(m_count-1);
         rem_buf.upd(rem_count, rem);
         rem_count <= rem_count + 1;
      end else
      begin
         let opd1 = buffer.sub(a_count);
         let opd2 = buffer.sub(a_count+1);
         $display("%3d:%2d:%2d ADD: %h %h", $time, a_count, m_count, opd1, opd2);
         fpu_add.request.put(tuple3(opd1, opd2, defaultValue));
         a_count <= a_count + 2;
         if(a_count == m_count-2) begin
            a_free <= False;
         end
      end
   endrule
   rule rl_pairwise_end(state == STATE_ADD && a_free && m_count == 1);
      $display("%3d: STATE_REM", $time);
      //acc <= buffer.sub(0);
      rem_buf.upd(rem_count, buffer.sub(0));
      rem_count <= rem_count + 1;
      state <= STATE_REM;
      rem_free <= True;
   endrule
   Reg#(UInt#(16)) ar_count <- mkReg(0);
   rule rl_pairwise_add_resp(state == STATE_ADD); // No simultaneous buffer access...
      match { .res, .exc } <- fpu_add.response.get();
      $display("%3d:%2d:%2d Add Result: %h", $time, ar_count, m_count, pack(res));
      let place_idx = ar_count/2;
      buffer.upd(place_idx, res);
      if(ar_count == m_count-2) begin
         a_free <= True;
         m_count <= m_count/2;
         a_count <= 0;
         ar_count <= 0;
      end else
      begin
         ar_count <= ar_count + 2;
      end
   endrule
   // remainder sequential add...
   rule rl_rem_add_req(state == STATE_REM && rem_free && rem_count >= 1);
      let opd1 = buffer.sub(extend(rem_count-1));
      let opd2 = acc;
      fpu_add.request.put(tuple3(opd1, opd2, defaultValue));
      rem_free <= False;
      rem_count <= rem_count - 1;
   endrule
   rule rl_rem_add_resp(state == STATE_REM && !rem_free);
      match { .res, .exc } <- fpu_add.response.get();
      acc <= res;
      if(rem_count == 0) begin
         state <= STATE_COMPLETE;
         $display("%3d: STATE_COMPLETE", $time);
      end else
      begin
         rem_free <= True;
      end
   endrule
   
   Reg#(UInt#(16)) r_count <- mkReg(0);
   interface Put request;
      method Action put(MRequestUT m) if (state == STATE_READY);
         if(m matches tagged ReqOp .r) begin
            match { .opd1, .opd2 } = r;
            $display("%3d: PUT: %h %h", $time, opd1, opd2);
            fpu_mult.request.put (tuple3(opd1, opd2, defaultValue));
            if(r_count == alloc_size-1) begin
               state <= STATE_MULT;
               $display("%3d: STATE_MULT", $time);
            end
            r_count <= r_count + 1;
         end 
         else if(m matches tagged Init .a) begin
            $display("%3d: Init", $time);
            alloc_size <= a;
            m_count <= 0;
            r_count <= 0;
            a_count <=0;
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

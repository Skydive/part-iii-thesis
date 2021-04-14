package Accel_Internal;

export Accel_Internal_IFC, mkAccel_Internal;

import Vector :: *;

interface Accel_Internal_IFC;
   method Action execute_command(Accel_Cmd cmd);
   method Action sub(Bit#(32) local_addr);
   method Action upd(Bit#(32) local_addr, Bit#(32) value);

endinterface

module Accel_Internal(Accel_Internal_IFC);
   Vector #(512, Reg #(Bit #(8))) rgv_data <- replicateM(mkReg(0));
   
endmodule

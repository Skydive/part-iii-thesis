package Pusher;

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
module mkPusher(Empty);
   Integer alloc_size = 4;
   Integer numServers = 2;
   RegFile #(Bit #(32), FSingle) rf <- mkRegFileLoad ("array1.hex", 0, fromInteger(alloc_size) - 1);

   Vector#(5,Vector#(256, Reg#(FSingle))) server_mem <- replicateM(replicateM(mkReg(0)));
   Vector#(5,Server#(MRequestUT, FSingle)) servers <- replicateM(mkZipReduceUnit);


endmodule
endpackage

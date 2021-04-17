package MultiPortBRAM;

import Vector :: *;
import RegFile :: *;
import ConfigReg :: *;

interface MultiPortBRAM#(type addr, type data, numeric type n);
   method Action upd(addr a, data x);
   method ActionValue#(data) sub(Bit#(32) bank, addr a);
endinterface
module mkMultiPortBRAM(MultiPortBRAM#(addr, data, n))
provisos(
   Bits#(addr, addr_sz),
   Bits#(data, data_sz),
   Bounded#(addr)
   );

   Vector#(n, RegFile#(addr, data)) mem <- replicateM(mkRegFileWCF(minBound, maxBound));

   method Action upd(addr a, data x);
      for(Integer i=0; i<valueOf(n); i=i+1)
         mem[i].upd(a, x);
   endmethod
   
   method ActionValue#(data) sub(Bit#(32) bank, addr a);
      return mem[bank].sub(a);
   endmethod
   
endmodule
endpackage

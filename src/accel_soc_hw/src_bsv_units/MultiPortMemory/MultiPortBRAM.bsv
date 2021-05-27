package MultiPortBRAM;

import Vector :: *;
import RegFile :: *;
import ConfigReg :: *;

interface MultiPortBRAM_IFC#(type addr, type data, numeric type n);
   method Action upd(addr a, data x);
   method ActionValue#(data) sub(Bit#(8) c, addr a);
endinterface
module mkMultiPortBRAM#(Integer low, Integer high)(MultiPortBRAM_IFC#(addr, data, n))
provisos(
   Bits#(addr, addr_sz),
   Bits#(data, data_sz),
   Literal#(addr)
   );

   Vector#(n, RegFile#(addr, data)) mem <- replicateM(mkRegFileWCF(fromInteger(low), fromInteger(high)));

   method Action upd(addr a, data x);
      for(Integer i=0; i<valueOf(n); i=i+1)
         mem[i].upd(a, x);
   endmethod
   
   method ActionValue#(data) sub(Bit#(8) c, addr a);
      return mem[c].sub(a);
   endmethod
   
endmodule
endpackage

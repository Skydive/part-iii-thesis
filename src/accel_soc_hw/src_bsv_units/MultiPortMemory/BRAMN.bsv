
import Vector :: *;
import RegFile :: *;
import ConfigReg :: *;

interface MultiPortBRAM#(type addr, type data, numeric type n, numeric type data_bytes);
   method Action upd(addr a, data x);
   method ActionValue#(data) sub(Bit#(32) bank, addr a);
endinterface
module mkMultiPortBRAM(MultiPortBRAM#(addr, data, n))
provisos(
   Bits#(addr, addr_sz),
   Bounded#(addr),
   Bits#(data, data_sz),
   Mul#(data_bytes, 8, data_sz),
   Div#(data_sz, 8, data_bytes)
   );

   Vector#(n, RegFile#(data)) mem <- replicateM(mkRegFileWCF(minBound, maxBound));

   method Action upd(addr a, data x);
      for(Integer i=0; i<n; i++)
         mem[i].upd(a, x);
   endmethod
   
   method ActionValue#(data) sub(Bit#(32) bank, addr a);
      return mem[bank].sub(a);
   endmethod
   
endmodule

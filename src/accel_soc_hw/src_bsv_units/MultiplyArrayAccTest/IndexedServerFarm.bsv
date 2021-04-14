package IndexedServerFarm;

import FIFO::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import ClientServer::*;
import Connectable::*;
import List::*;
import Assert::*;

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

module mkZipReduceFarm#(Integer numServers)
     (Server#(requestT,responseT))
      provisos(Bits#(requestT,requestTwidth), Bits#(responseT,responseTwidth));

  staticAssert(numServers > 1, "ServerFarm: number of servers must be > 1.");
  staticAssert(numServers < 65, "ServerFarm: number of servers must be < 65.");

  Reg#(Bit#(numServers)) occupancy_bits <- mkReg(0);
  List#(Tuple2#(Reg#(MatUnitArgs), Server#(requestT,responseT))) servers <- replicateM(numServers, mkServer);

  Reg#(UInt#(6)) write_server <- mkReg(0);
  Reg#(UInt#(6)) read_server  <- mkReg(0);
 ff
  FIFOF#(requestT)  request_fifo  <- mkBypassFIFOF;
  FIFOF#(responseT) response_fifo <- mkBypassFIFOF;

  function Integer nextServer(Integer n);
    let next = n+1;
    return (next>=numServers) ? 0 : next;
  endfunction

  for(Integer j=0; j<numServers; j=j+1)
    begin                        
      rule put_requests (write_server == fromInteger(j));
        let r = request_fifo.first;
        request_fifo.deq;
        servers[j].request.put(r);
        write_server <= fromInteger(nextServer(j));
      endrule
      rule gather_results (read_server == fromInteger(j));
        let result <- servers[j].response.get;
        response_fifo.enq(result);
        read_server <= fromInteger(nextServer(j));
      endrule
    end               

  interface Put request = toPut(request_fifo);
  interface Get response = toGet(response_fifo);
   
endmodule

endpackage

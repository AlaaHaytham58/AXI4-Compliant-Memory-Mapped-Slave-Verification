//this packet will cover constraints,sample,coverage and randomization of axi packet
package axi_packet_all;

import axi_enum_packet::*;

//--- MISSING SIGNALS: AWVALID,WLAST,WVALID,BREADY,ARVALID,RREADY ---
class axi_packet #(parameter  ADDR_WIDTH = 16, 
                  parameter  DATA_WIDTH = 32, 
                  parameter MemoryDepth = 1024);
                  
// Write randomization variables
  rand logic [ADDR_WIDTH-1:0] awaddr;
  rand logic [7:0] awlen;
  rand logic [2:0] awsize;
  rand logic [DATA_WIDTH-1:0] wdata[];

//read randomization variables
  rand logic [ADDR_WIDTH-1:0] araddr;
  rand logic [7:0] arlen;
  rand logic [2:0] arsize;

// randomization variables for response
  rand axi_resp_e axi_resp;
  rand axi_access_e axi_access;
  rand boundary_e inlimit;

  //array of data for write
  rand logic [DATA_WIDTH-1:0] data_array[];

//Constraints
    constraint align_addr {
    awaddr % 4 == 0;
    araddr % 4 == 0;
    }

    constraint fixed_size {
    awsize == 2; 
    arsize == 2;
    }

    constraint burst_len_limit {
    awlen inside {[0:15]};
    arlen inside {[0:15]};
    }

    constraint boundary_limit{
    inlimit dist {INLIMIT :=50, OUTLIMIT:=50};
    }

    constraint axi_response {
         axi_resp dist {RESP_OKAY:=40, RESP_EXOKAY:=40, RESP_SLVERR:=20};
    }

    constraint axi_access_type {
            axi_access dist {ACCESS_READ:=50, ACCESS_WRITE:=50};
    }

    constraint axi_boundary_size_write{
      if (inlimit == INLIMIT)
      ((awaddr & 12'hFFF) + ((awlen + 1) * (1 << 2))) <= 4096;    
    }

    constraint axi_boundary_size_read {
    if (axi_access == ACCESS_READ && inlimit == INLIMIT)
      ((araddr & 12'hFFF) + ((arlen + 1) * (1 << 2))) <= 4096;
    }

function randarr();
  data_array = new[awlen + 1];

  foreach (data_array[i]) begin
    data_array[i] = $urandom_range(0, 2**DATA_WIDTH - 1);
  end
endfunction

//coverage
covergroup cg;
//---------------write coverage----------------
coverpoint awaddr {
  bins aligned_addr[] = {[0:2**ADDR_WIDTH-1]};
  ignore_bins unaligned_addr = {[0:2**ADDR_WIDTH-1]} with (item % 4 != 0);
}
coverpoint awlen {
  bins burst_len[] = {[0:15]};
}
coverpoint awsize {
  bins size_4B = {2};
  
}
//-----------read coverage-----------------
coverpoint araddr {
    bins aligned_addr[] = {[0:2**ADDR_WIDTH-1]};
    ignore_bins unaligned = {[0:2**ADDR_WIDTH-1]} with (item % 4 != 0);
}
coverpoint arlen {
    bins burst_len[] = {[0:15]};
}
coverpoint arsize {
    bins size_4B = {2};
}
//--------------common part-----------------
coverpoint axi_resp {
  bins resp_okay = {RESP_OKAY};
  bins resp_exokay = {RESP_EXOKAY};
  bins resp_slverr = {RESP_SLVERR};
}
coverpoint axi_access {
  bins access_read = {ACCESS_READ};
  bins access_write = {ACCESS_WRITE};
}
coverpoint inlimit {
  bins inlimit = {INLIMIT};
  bins outlimit = {OUTLIMIT};
}
//---------------crossing----------------
cross awlen, awsize, axi_resp, axi_access, inlimit;
cross arlen, arsize, axi_resp, axi_access, inlimit;
endgroup
 function new();
    cg = new();
  endfunction

  function void sample();
    this.cg.sample();
  endfunction
endclass

endpackage
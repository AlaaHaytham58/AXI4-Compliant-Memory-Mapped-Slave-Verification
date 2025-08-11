package axi_enum_packet;
// might needed enums
// enum for AXI states
// AXI states for read and write channels
//axi handshake states

//WRITE/READ states
/*
typedef enum logic [2:0] {
  W_IDLE = 3'd0,
  W_ADDR = 3'd1,
  W_DATA = 3'd2,
  W_RESP = 3'd3
} write_state_e;

typedef enum logic [2:0] {
  R_IDLE = 3'd0,
  R_ADDR = 3'd1,
  R_DATA = 3'd2
} read_state_e;*/

//////////////////////////////////////////////
//AXI RESPONSE 
typedef enum logic [1:0] {
  RESP_OKAY   = 2'b00,
  RESP_EXOKAY = 2'b01, 
  RESP_SLVERR = 2'b10
} axi_resp_e;

///////////////////////////////////////////////
// Access Type Enum
typedef enum logic {
  ACCESS_READ  = 1'b0,
  ACCESS_WRITE = 1'b1
} axi_access_e;
///////////////////////////////////////////////
typedef enum {
    INLIMIT,
    OUTLIMIT
}boundary_e;

//Memory read/write
typedef enum logic [1:0] {
	OFF,
	READ = 2'b10,
	WRITE
} memory_en_e;
endpackage 
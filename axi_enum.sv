package axi_enum;
// might needed enums
// enum for AXI states
// AXI states for read and write channels
//axi handshake states
//Memory read/write
typedef enum logic [1:0] {
	OFF,
	READ = 2'b10,
	WRITE
} memory_en_e;

endpackage 
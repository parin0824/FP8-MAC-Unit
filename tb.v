module testbench;
 // Clock and reset
 reg clk96;
 reg rst96;

 // Input vectors and results
 reg [7:0] A96 [0:11], B96 [0:11];
 reg [7:0] accum96; // Accumulator (Stores Dot Product)
 wire [7:0] mult_result96, accum_result96; // Intermediate results

 // Registers for current operands
 reg [7:0] current_a96, current_b96;

 integer i96;

 // Instantiate Pipelined FP8 Multiplier and Adder
 fp8_mult_pipelined mult_inst96 (
 .clk96(clk96),
 .rst96(rst96),
 .a96(current_a96),
 .b96(current_b96),
 .result96(mult_result96)
 );

 fp8_add_pipelined add_inst96 (
 .clk96(clk96),
 .rst96(rst96),
 .a96(accum96),
 .b96(mult_result96),
 .result96(accum_result96)
 );

 // Clock generation
 always begin
 #5 clk96 = ~clk96; // 10ns clock period
 end

 // Waveform dump and test procedure
 initial begin
 // Initialize signals
 clk96 = 0;
 rst96 = 1;
 accum96 = 8'b00000000;
 current_a96 = 8'b00000000;
 current_b96 = 8'b00000000;
7

 // Initialize test vectors
 A96[0] = 8'b00110011; B96[0] = 8'b00111000;
 A96[1] = 8'b00110110; B96[1] = 8'b10101100;
 A96[2] = 8'b00111000; B96[2] = 8'b00110100;
 A96[3] = 8'b10111001; B96[3] = 8'b01001000;
 A96[4] = 8'b00111100; B96[4] = 8'b01001011;
 A96[5] = 8'b01000000; B96[5] = 8'b11000110;
 A96[6] = 8'b01000010; B96[6] = 8'b00111001;
 A96[7] = 8'b01000100; B96[7] = 8'b01000100;
 A96[8] = 8'b11000110; B96[8] = 8'b00110011;
 A96[9] = 8'b01001000; B96[9] = 8'b00110110;
 A96[10] = 8'b01001011; B96[10] = 8'b10111100;
 A96[11] = 8'b01001100; B96[11] = 8'b01000011;

 $dumpfile("waveform.vcd");
 $dumpvars(0, testbench);

 // Reset sequence
 #20 rst96 = 0; // Release reset after 2 clock cycles

 // Run test vectors with pipeline considerations
 for (i96 = 0; i96 < 12; i96 = i96 + 1) begin
 @(posedge clk96); // Synchronize to clock

 // Input new operands
 current_a96 = A96[i96];
 current_b96 = B96[i96];


 // We need to wait for pipeline stages to complete
 // For results, we need to wait 3 cycles for multiply and 3 more for add
 if (i96 >= 6) begin // After 6 cycles, we start seeing valid result
 // Update accumulator after results are valid
 @(posedge clk96); // Wait one more cycle to capture result
 accum96 = accum_result96;
 end
 end
 // Run additional cycles to flush the pipeline
 repeat (10) @(posedge clk96);

 $finish;
 end

 // Monitor for debug
 initial begin
 $monitor("Time: %t, CLK: %b, RST: %b, A: %b, B: %b, MULT: %b, ACCUM: %b, RESULT: %b",
 $time, clk

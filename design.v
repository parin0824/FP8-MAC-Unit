// Pipelined FP8 Multiplier
module fp8_mult_pipelined (
 input wire clk96,
 input wire rst96,
 input wire [7:0] a96,
 input wire [7:0] b96,
 output reg [7:0] result96
);
 // Stage 1 Registers
- Multiply
 reg sign_mult96;
 reg [2:0] exp_sum96;
 reg [15:0] mant_prod96;

 // Stage 2 Registers
- Normalize
 reg sign_norm96;
 reg [2:0] norm_exp96;
 reg [7:0] norm_mant96;

 // Stage 1: Multiply
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 sign_mult96 <= 1'b0;
 exp_sum96 <= 3'b000;
 mant_prod96 <= 16'b0;
 end else begin
 // Extract operands
 sign_mult96 <= a96[7] ^ b96[7];
 exp_sum96 <= a96[6:4] + b96[6:4]
- 3;
 mant_prod96 <= {1'b1, a96[3:0]} * {1'b1, b96[3:0]};
 end
 end

 // Stage 2: Normalize
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 sign_norm96 <= 1'b0;
 norm_exp96 <= 3'b000;
 norm_mant96 <= 8'b0;
 end else begin
 sign_norm96 <= sign_mult96;

 if (mant_prod96[15]) begin
 norm_mant96 <= mant_prod96[14:7];

 // Clamp exponent
 if (exp_sum96 + 1 > 7)
3
 norm_exp96 <= 3'b111;
 else if (exp_sum96 + 1 < 0)
 norm_exp96 <= 3'b000;
 else
 norm_exp96 <= exp_sum96 + 1;
 end else begin
 norm_mant96 <= mant_prod96[13:6];

 // Clamp exponent
 if (exp_sum96 > 7)
 norm_exp96 <= 3'b111;
 else if (exp_sum96 < 0)
 norm_exp96 <= 3'b000;
 else
 norm_exp96 <= exp_sum96;
 end
 end
 end

 // Stage 3: Round
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 result96 <= 8'b0;
 end else begin
 // Compose final result (round to 4 bits)
 result96 <= {sign_norm96, norm_exp96, norm_mant96[6:3]};
 end
 end
endmodule
// Pipelined FP8 Adder
module fp8_add_pipelined (
 input wire clk96,
 input wire rst96,
 input wire [7:0] a96,
 input wire [7:0] b96,
 output reg [7:0] result96
);
 // Stage 1 Registers - Align
 reg sign_a_align96, sign_b_align96;
 reg [2:0] exp_out_align96;
 reg [7:0] mant_a_align96, aligned_mant_align96;

 // Stage 2 Registers - Add
 reg sign_add96;
 reg [2:0] exp_out_add96;
 reg [7:0] mant_sum96;

 // Stage 3 Registers - Normalize
 reg [7:0] norm_mant96;
 reg [2:0] norm_exp96;
4

 // Stage 1: Align
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 sign_a_align96 <= 1'b0;
 sign_b_align96 <= 1'b0;
 exp_out_align96 <= 3'b000;
 mant_a_align96 <= 8'b0;
 aligned_mant_align96 <= 8'b0;
 end else begin
 // Extract components
 sign_a_align96 <= a96[7];
 sign_b_align96 <= b96[7];

 // Align exponents
 if (a96[6:4] > b96[6:4]) begin
 exp_out_align96 <= a96[6:4];
 mant_a_align96 <= {1'b1, a96[3:0]};
 // Shift b's mantissa by the exponent difference
 aligned_mant_align96 <= {1'b1, b96[3:0]} >> (a96[6:4] - b96[6:4]);
 end else begin
 exp_out_align96 <= b96[6:4];
 mant_a_align96 <= {1'b1, b96[3:0]};
 // Shift a's mantissa by the exponent difference
 aligned_mant_align96 <= {1'b1, a96[3:0]} >> (b96[6:4] - a96[6:4]);
 end
 end
 end

 // Stage 2: Add
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 sign_add96 <= 1'b0;
 exp_out_add96 <= 3'b000;
 mant_sum96 <= 8'b0;
 end else begin
 exp_out_add96 <= exp_out_align96;

 // Handle sign in addition
 if (sign_a_align96 == sign_b_align96) begin
 mant_sum96 <= mant_a_align96 + aligned_mant_align96;
 sign_add96 <= sign_a_align96;
 end else begin
 if (mant_a_align96 > aligned_mant_align96) begin
 mant_sum96 <= mant_a_align96 - aligned_mant_align96;
 sign_add96 <= sign_a_align96;
 end else begin
 mant_sum96 <= aligned_mant_align96 - mant_a_align96;
 sign_add96 <= sign_b_align96;
 end
 end
5
 end
 end

 // Stage 3: Normalize
 always @(posedge clk96 or posedge rst96) begin
 if (rst96) begin
 norm_mant96 <= 8'b0;
 norm_exp96 <= 3'b000;
 result96 <= 8'b0;
 end else begin
 // Normalize mantissa logic
 if (mant_sum96[7]) begin
 // MSB is set, may need to shift right
 norm_mant96 <= mant_sum96 >> 1;
 norm_exp96 <= (exp_out_add96 < 7) ? exp_out_add96 + 1 : 3'b111;
 end else if (mant_sum96[6]) begin
 // Already normalized
 norm_mant96 <= mant_sum96;
 norm_exp96 <= exp_out_add96;
 end else if (mant_sum96[5]) begin
 norm_mant96 <= mant_sum96 << 1;
 norm_exp96 <= (exp_out_add96 > 0) ? exp_out_add96 - 1 : 3'b000;
 end else if (mant_sum96[4]) begin
 norm_mant96 <= mant_sum96 << 2;
 norm_exp96 <= (exp_out_add96 > 1) ? exp_out_add96 - 2 : 3'b000;
 end else if (mant_sum96[3]) begin
 norm_mant96 <= mant_sum96 << 3;
 norm_exp96 <= (exp_out_add96 > 2) ? exp_out_add96 - 3 : 3'b000;
 end else if (mant_sum96[2]) begin
 norm_mant96 <= mant_sum96 << 4;
 norm_exp96 <= (exp_out_add96 > 3) ? exp_out_add96 - 4 : 3'b000;
 end else if (mant_sum96[1] || mant_sum96[0]) begin
 norm_mant96 <= mant_sum96 << 5;
 norm_exp96 <= (exp_out_add96 > 4) ? exp_out_add96 - 5 : 3'b000;
 end else begin
 // Result is zero
 norm_mant96 <= 8'b0;
 norm_exp96 <= 3'b000;
 end

 // Compose final result
 result96 <= {sign_add96, norm_exp96, norm_mant96[6:3]};
 end
 end
endmodule

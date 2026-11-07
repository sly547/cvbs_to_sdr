// Copyright (c) 2026 Michael Büchler
// All Rights Reserved.
//
// TODO: figure out how to license this. CERN-OHL-W-2.0 seems a bit
// complicated with the requirement to document changes.

// initial: no VSB, just copy the signal to both I and Q
// better: apply a VSB filter, making the data complex
// amazing: take in audio data, add an audio carrier
module cvbs_to_sdr
#(
    parameter int N = 16
)
(
    // This initial version also transfers the data into the SDR's sampling
    // clock, which is 4x the video clock.
    // Later: do't do this, perform VSB filtering after this module, then
    // bring it into the target clock domain.
    // Alternative: filter at the target clock domain (less latency).
    input logic clk_in,
    input logic clk_out,

    input rst_out_n,

    input logic vblank,
    input logic vsync,
    input logic hblank,
    input logic hsync,
    input logic colorburst,
    input logic signed [12-1:0] cvbs,

    output logic data_valid,
    output logic signed [N-1:0] data_out_i,
    output logic signed [N-1:0] data_out_q
);

localparam int SCALE_WL = 8;
localparam int CVBS_WL = 12;

typedef logic signed [SCALE_WL-1:0] scale_inv_t;
typedef logic signed [SCALE_WL+CVBS_WL-1:0] product_t;
typedef logic signed [CVBS_WL-1:0] cvbs_t;
typedef logic signed [CVBS_WL:0] cvbs_sum_t;

// Q0.7 for -0.65
//const logic signed [7:0] scale_and_invert = -8'sd83;
const scale_inv_t scale_and_invert = scale_inv_t'(-83);
// Q11.0 * Q0.7 = Q11.7 (stored as 20 bits because both inputs have a sign bit)
product_t cvbs_inv_pre;
// Q11.0
cvbs_t cvbs_inv;
cvbs_sum_t cvbs_out_pre;
cvbs_t cvbs_out;
cvbs_t data_out;

logic [1:0] ctr;

const cvbs_t sync_lvl = {1'b0, {11{1'b1}}}; // complicated way of saying 2**11-1
const cvbs_t blank_lvl = cvbs_t'(1536);

// the target range of video data is between 10% and 75% of the positive
// output range, so 65% of the original amplitude
always_ff @(posedge clk_in) begin
    cvbs_inv_pre <= scale_and_invert * cvbs;
end
// throw out 7 bits because the scaling factor is Q0.7
assign cvbs_inv = cvbs_inv_pre[18:SCALE_WL-1];
assign cvbs_out_pre = cvbs_sum_t'(cvbs_inv) + cvbs_sum_t'(blank_lvl);

always_comb begin
    // negative sign: should not be possible!
    if (cvbs_out_pre[CVBS_WL]) begin
        if (cvbs_out_pre[CVBS_WL-1] != 1'b1) begin
            cvbs_out = {1'b1, {(CVBS_WL-1){1'b0}}}; // negative max
        end
        else begin
            cvbs_out = cvbs_out_pre[CVBS_WL-1:0];
        end
    // positive sign
    end else begin
        if (cvbs_out_pre[CVBS_WL-1] != 1'b0) begin
            // should never happen unless the color carrier exceeds the
            // sync level
            cvbs_out = {1'b0, {(CVBS_WL-1){1'b1}}}; // positive max
        end
        else begin
            cvbs_out = cvbs_out_pre[CVBS_WL-1:0];
        end
    end
end

always_comb begin
    if (vsync || hsync)
        data_out = sync_lvl;
    else if (colorburst)
        data_out = cvbs_out;
    else if (vblank || hblank)
        data_out = blank_lvl;
    else
        data_out = cvbs_out;
end

always_ff @(posedge clk_out) begin
    if (!rst_out_n) begin
        ctr <= 2'b0;
        data_valid <= 1'b0;
    end
    else begin
        ctr++;
        if (ctr == 2'b0)
            data_valid <= 1'b1;
        else
            data_valid <= 1'b0;

        data_out_i <= (N'(data_out)) << (N-12);
        data_out_q <= (N'(data_out)) << (N-12);
        //data_out_q <= {data_out, 4'b0};
    end
end

endmodule: cvbs_to_sdr

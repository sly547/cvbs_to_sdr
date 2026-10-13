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
    input logic signed [12-1:0] cvbs,

    output logic data_valid,
    output logic signed [N-1:0] data_out_i,
    output logic signed [N-1:0] data_out_q
);

// Q0.7 for -0.65
const logic signed [7:0] scale_and_invert = -8'd83;
// Q11.0 * Q0.7 = Q11.7 (stored as 20 bits because both inputs have a sign bit)
logic signed [19:0] cvbs_inv_pre;
// Q11.0
logic signed [11:0] cvbs_inv;
logic signed [12:0] cvbs_out_pre;
logic signed [11:0] cvbs_out;
logic signed [11:0] data_out;

logic [1:0] ctr;

const logic signed [11:0] sync_lvl = {1'b0, {11{1'b1}}}; // complicated way of saying 2**11-1
const logic signed [11:0] blank_lvl = 12'd1536;

// the target range of video data is between 10% and 75% of the positive
// output range, so 65% of the original amplitude
always_ff @(posedge clk_in) begin
    cvbs_inv_pre <= scale_and_invert * cvbs;
end
assign cvbs_inv = cvbs_inv_pre[18:7];
assign cvbs_out_pre = 13'(cvbs_inv) + 13'(blank_lvl);
assign cvbs_out = cvbs_out_pre[11:0]; // FIXME broken resize if pre exceeds 12 bits

always_comb begin
    if (vsync || hsync)
        data_out = sync_lvl;
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

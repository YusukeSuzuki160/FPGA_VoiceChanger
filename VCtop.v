module VCtop (
	       	 //////////// CLOCK //////////
		 input 	      CLOCK_50,
		 
		 //////////// KEY //////////
		 input [3:0]  KEY,
		 
		 //////////// SW //////////
		 input [9:0]  SW,
		 
		 //////////// LED //////////ledr
		 output [9:0] LEDR,
		 
		 //////////// Seg7 //////////
		 output [6:0] HEX0,
		 output [6:0] HEX1,
		 output [6:0] HEX2,
		 output [6:0] HEX3,
		 output [6:0] HEX4,
		 output [6:0] HEX5,
		 
		 //////////// VGA //////////
		 output       VGA_BLANK_N,
		 output [7:0] VGA_B,
		 output       VGA_CLK,
		 output [7:0] VGA_G,
		 output       VGA_HS,
		 output [7:0] VGA_R,
		 output       VGA_SYNC_N,
		 output       VGA_VS, 
		 //////////// AUDIO //////////
		 input 	      AUD_ADCDAT,
		 inout 	      AUD_ADCLRCK,
		 inout 	      AUD_BCLK,
		 output       AUD_DACDAT,
		 inout 	      AUD_DACLRCK,
		 output       AUD_XCK,
		 
		 //////////// I2C for Audio and Video-In //////////
		 output       FPGA_I2C_SCLK,
		 inout 	      FPGA_I2C_SDAT,
		 //////////// IR //////////
		 input 	      IRDA_RXD,
		 output       IRDA_TXD
		 );
   
   
   wire [10:0] 		      VGA_X;
   wire [10:0] 		      VGA_Y;
   
   wire 		      CLK40;
   
   
   wire [7:0] 		      posx, posy;
	wire [2:0] 		      posr, posg, posb;
   
   ///=======================================================
   //  REG/WIRE declarations
   //=======================================================
   	wire 		      CLK_1M;
   	wire 		      END;
  	wire 		      KEY0_EDGE;
   	wire [23:0] 		      AUD_I2C_DATA;
   	wire 		      GO;
   
   //=======================================================
   //  Structural coding
   //=======================================================

   	reg [15:0] 		      SL, SR, SoR, SoL;
   	reg 			      ADCLR1, DACLR1;
  	reg [3:0] 		      FlagLR, FlagOLR;
   	reg 			      FlagIn, FlagOut;
   	reg 			      AO;
	reg [63:0] fft1, fft2, ifft1, ifft2; // register for path among fft or ifft. 
    reg [63:0] fft_out, ifft_out; // register for path among fft or ifft.
    reg regHEAD1[0:4], regHEAD2[0:4], regHEAD3[0:3], iregHEAD1[0:4], iregHEAD2[0:4], iregHEAD3[0:3]; // register for path among fft or ifft.
    reg [1:0] fft_phase1, fft_phase2, fft_phase3, ifft_phase1, ifft_phase2, ifft_phase3; // register for path among fft or ifft.
    reg [63:0] stage_1[0:111], stage_2[0:27], stage_3[0:6], istage_1[0:111], istage_2[0:27], istage_3[0:6]; // shift register for fft or ifft.
    wire signed [31:0] d1_real, d1_imag, d2_real, d2_imag, id1_real, id1_imag, id2_real, id2_imag;
    reg [63:0] reorder_reg[0:63], reorder_buf[0:63], ireorder_reg[0:63], ireorder_buf[0:63]; // reorder register and buffer.
    reg [5:0] reorder_cnt, reorder_write, ireorder_cnt, ireorder_write; // reorder counter.
    reg [63:0] aud_in; // audio input and output.
    reg signed [31:0] sin[0:63], cos[0:63]; // ROM of sin and cos.
    reg AUDIO_HEAD,REOR_HEAD, OUT_HEAD;
    reg [5:0] read_counter;
    reg [5:0] fftcount1;
    reg [5:0] fftcount2;
    reg [63:0] reorder_out;
    reg [5:0] rocnt;
    reg flag_in;
    reg [5:0] ifftcount1;
    reg [5:0] ifftcount2;
    reg [63:0] ireorder_out;
    reg [5:0] irocnt;
    reg iflag_in;
    reg swap_in, iswap_in;
	reg clk;
	reg out_flag;
	reg [5:0] Sin;

    wire [63:0] fft1_R[0:6], fft2_R[0:6], fft3_R[0:6], ifft1_R[0:6], ifft2_R[0:6], ifft3_R[0:6];
    wire signed [31:0] fft1_U_re[0:3], fft2_U_re[0:3], fft3_U_re[0:3], ifft1_U_re[0:3], ifft2_U_re[0:3], ifft3_U_re[0:3];
    wire signed [31:0] fft1_U_im[0:3], fft2_U_im[0:3], fft3_U_im[0:3], ifft1_U_im[0:3], ifft2_U_im[0:3], ifft3_U_im[0:3];

    integer i, j, l;
    initial begin
		$readmemb("/home/sysele2207/Voicechanger/sin_64.txt", sin);
        $readmemb("/home/sysele2207/Voicechanger/cos_64.txt", cos);
		//$readmemb("E:/eeic/eeic3A/experiment_2/VoiceChange/sin_64.txt", sin);
        //$readmemb("E:/eeic/eeic3A/experiment_2/VoiceChange/cos_64.txt", cos);
    end
    wire NRST;
    assign NRST = KEY[0];
    //assign		AUD_DACDAT = AUD_ADCDAT;
   	assign		AUD_DACDAT = AUD_DACLRCK == 0 ? SoL[15] : SoR[15];

	wire [31:0] aud_out;
	assign aud_out = $signed(ireorder_out[31:0]) >>> 6;
   
   	always @(posedge AUD_BCLK) begin
      	if( !NRST ) begin
	 		FlagLR <= 0;
	 		FlagOLR <= 0;
	 		FlagIn <= 0;
	 		FlagOut <= 0;
	 		SR <= 0;
	 		SL <= 0;
        	AUDIO_HEAD <= 0;
			clk <= 0;
            out_flag <= 0;
			Sin <= 0;
			aud_in <= 0;
      	end else begin
	 		ADCLR1 <= AUD_ADCLRCK;
	 		DACLR1 <= AUD_DACLRCK;
	 		if( FlagOut == 1 ) begin
	    		if( FlagOLR == 15 ) FlagOut <= 0;
	    		FlagOLR <= FlagOLR + 4'd1;
	    		if( AUD_DACLRCK == 0 ) SoL <= {SoL[14:0],1'b0};
	    		else SoR <= {SoR[14:0],1'b0};
	 		end else begin
				if (OUT_HEAD) begin
					out_flag <= 1;
				end
				if (out_flag) begin
	    			if( DACLR1 == 1 && AUD_DACLRCK == 0 ) begin
	       					FlagOLR <= 0;
	       					FlagOut <= 1;
	    					SoL <= aud_out[15:0];
							SoR <= aud_out[15:0];
							//SoL <= SL;
							//SoR <= SR;	
	    			end else if( ADCLR1 == 0 && AUD_ADCLRCK == 1 )begin
	       					FlagOLR <= 0;
	       					FlagOut <= 1;
	    			end
				end else begin
					if( DACLR1 == 1 && AUD_DACLRCK == 0 ) begin
	       					FlagOLR <= 0;
	       					FlagOut <= 1;
	    					SoL <= 0;
							SoR <= 0;
	    			end else if( ADCLR1 == 0 && AUD_ADCLRCK == 1 )begin
	       					FlagOLR <= 0;
	       					FlagOut <= 1;
	    			end
				end
	 		end
	 		if( FlagIn == 1 ) begin
	    		if( FlagLR == 15 ) begin
					FlagIn <= 0;
				end
	    		FlagLR <= FlagLR + 1;
				AUDIO_HEAD <= 0;
				if (FlagLR == 7) begin 
					clk <= 0;
				end
	    		if( AUD_ADCLRCK == 0 ) SL <= {SL[14:0],AUD_ADCDAT};
	    		else SR <= {SR[14:0],AUD_ADCDAT};
	 		end else begin
	    		if( ADCLR1 == 1 && AUD_ADCLRCK == 0 )begin
	       			aud_in <= {{16{SL[15]}}, SL, 32'b0};
					//aud_in <= {16'b0, SL, 32'b0};
	       			SL <= 0;
	      			FlagIn <= 1;
	       			FlagLR <= 0;
					Sin <= Sin + 1;
					if (Sin == 0) begin
						AUDIO_HEAD <= 1;
					end else begin
						AUDIO_HEAD <= 0;
					end
					clk <= 1;
	    		end else if( ADCLR1 == 0 && AUD_ADCLRCK == 1 )begin
	       			SR <= 0;
	       			FlagIn <= 1;
	       			FlagLR <= 0;
	    		end
	 		end
	  	end
	end

	// structure for fft //
    // stage1 //
    assign fft1_R[0] = stage_1[96];
    assign fft1_R[1] = stage_1[80];
    assign fft1_R[2] = stage_1[64];
    assign fft1_R[3] = stage_1[48];
    assign fft1_R[4] = stage_1[32];
    assign fft1_R[5] = stage_1[16];
    assign fft1_R[6] = stage_1[0];
    assign fft1_U_re[0] = fft1_R[3][63:32];
    assign fft1_U_re[1] = (fft_phase1) > 0 ? fft1_R[4][63:32] : fft1_R[0][63:32];
    assign fft1_U_re[2] = (fft_phase1) > 1 ? fft1_R[5][63:32] : fft1_R[1][63:32];
    assign fft1_U_re[3] = (fft_phase1) > 2 ? fft1_R[6][63:32] : fft1_R[2][63:32];
    assign fft1_U_im[0] = fft1_R[3][31:0];
    assign fft1_U_im[1] = (fft_phase1) > 0 ? fft1_R[4][31:0] : fft1_R[0][31:0];
    assign fft1_U_im[2] = (fft_phase1) > 1 ? fft1_R[5][31:0] : fft1_R[1][31:0];
    assign fft1_U_im[3] = (fft_phase1) > 2 ? fft1_R[6][31:0] : fft1_R[2][31:0];
    
    assign d1_real = (fft_phase1 == 0) ? (fft1_U_re[0] + fft1_U_re[1] + fft1_U_re[2] + fft1_U_re[3]) : ((fft_phase1 == 1) ? fft1_U_re[1] + fft1_U_im[0] - fft1_U_re[3] - fft1_U_im[2] : ((fft_phase1 == 2) ? fft1_U_re[2] - fft1_U_re[1] + fft1_U_re[0] - fft1_U_re[3]: fft1_U_re[3] - fft1_U_im[2] - fft1_U_re[1] + fft1_U_im[0]));
    assign d1_imag = (fft_phase1 == 0) ? fft1_U_im[0] + fft1_U_im[1] + fft1_U_im[2] + fft1_U_im[3] : ((fft_phase1 == 1) ? fft1_U_im[1] - fft1_U_re[0] - fft1_U_im[3] + fft1_U_re[2] : ((fft_phase1 == 2) ? fft1_U_im[2] - fft1_U_im[1] + fft1_U_im[0] - fft1_U_im[3] : fft1_U_im[3] + fft1_U_re[2] - fft1_U_im[1] - fft1_U_re[0]));


    always @(posedge clk or negedge NRST) begin
        if (!NRST) begin
			fft_phase1 <= 0;
			regHEAD1[0] <= 0;
			regHEAD1[1] <= 0;
			regHEAD1[2] <= 0;
			regHEAD1[3] <= 0;
			regHEAD1[4] <= 0;
			fftcount1 <= 0;
			fft1 <= 0;
			for (i = 0; i < 112; i = i + 1) begin
				stage_1[i] <= 0;
			end
		end else begin
        	if (AUDIO_HEAD == 1 && regHEAD1[0] == 0) begin
            fft_phase1 <= 0;
            regHEAD1[0] <= AUDIO_HEAD;
            regHEAD1[1] <= regHEAD1[0];
            regHEAD1[2] <= regHEAD1[1];
            regHEAD1[3] <= regHEAD1[2];
            regHEAD1[4] <= regHEAD1[3];
            fftcount1 <= 1;
        end else if (fftcount1 == 15) begin
            fftcount1 <= 0;
            fft_phase1 <= fft_phase1 + 2'd1; 
        end else if (fftcount1 == 0) begin
            regHEAD1[0] <= AUDIO_HEAD;
            regHEAD1[1] <= regHEAD1[0];
            regHEAD1[2] <= regHEAD1[1];
            regHEAD1[3] <= regHEAD1[2];
            regHEAD1[4] <= regHEAD1[3];
            fftcount1 <= fftcount1 + 1;
        end else begin
            fftcount1 <= fftcount1 + 1;
        end
        
        stage_1[111] <= aud_in;
        for (i = 0; i < 111; i = i + 1) begin
            stage_1[i] <= stage_1[i + 1];
        end
        case (fft_phase1)
            0: begin
                fft1 <= {d1_real, d1_imag};
            end
            1: begin
                fft1 <= {(d1_real * (cos[fftcount1]) - d1_imag * (sin[fftcount1])) >>> 8, (d1_real * (sin[fftcount1]) + d1_imag * (cos[fftcount1])) >>> 8};
            end
            2: begin
                fft1 <= {(d1_real * (cos[fftcount1 * 2]) - d1_imag * (sin[fftcount1 * 2])) >>> 8, (d1_real * (sin[fftcount1 * 2]) + d1_imag * (cos[fftcount1 * 2])) >>> 8};
            end
            3:begin
                fft1 <= {(d1_real * (cos[fftcount1 * 3]) - d1_imag * (sin[fftcount1 * 3])) >>> 8, (d1_real * (sin[fftcount1 * 3]) + d1_imag * (cos[fftcount1 * 3])) >>> 8};
            end
        endcase
	end
	end

    // stage2 //

    assign fft2_R[0] = stage_2[24];
    assign fft2_R[1] = stage_2[20];
    assign fft2_R[2] = stage_2[16];
    assign fft2_R[3] = stage_2[12];
    assign fft2_R[4] = stage_2[8];
    assign fft2_R[5] = stage_2[4];
    assign fft2_R[6] = stage_2[0];
    assign fft2_U_re[0] = fft2_R[3][63:32];
    assign fft2_U_re[1] = (fft_phase2) > 0 ? fft2_R[4][63:32] : fft2_R[0][63:32];
    assign fft2_U_re[2] = (fft_phase2) > 1 ? fft2_R[5][63:32] : fft2_R[1][63:32];
    assign fft2_U_re[3] = (fft_phase2) > 2 ? fft2_R[6][63:32] : fft2_R[2][63:32];
    assign fft2_U_im[0] = fft2_R[3][31:0];
    assign fft2_U_im[1] = (fft_phase2) > 0 ? fft2_R[4][31:0] : fft2_R[0][31:0];
    assign fft2_U_im[2] = (fft_phase2) > 1 ? fft2_R[5][31:0] : fft2_R[1][31:0];
    assign fft2_U_im[3] = (fft_phase2) > 2 ? fft2_R[6][31:0] : fft2_R[2][31:0];
    
    assign d2_real =  (fft_phase2) == 0 ? (fft2_U_re[0] + fft2_U_re[1] + fft2_U_re[2] + fft2_U_re[3]) : ((fft_phase2 == 1) ? fft2_U_re[1] + fft2_U_im[0] - fft2_U_re[3] - fft2_U_im[2] : ((fft_phase2 == 2) ? fft2_U_re[2] - fft2_U_re[1] + fft2_U_re[0] - fft2_U_re[3]: fft2_U_re[3] - fft2_U_im[2] - fft2_U_re[1] + fft2_U_im[0]));

    assign d2_imag =  (fft_phase2) == 0 ? (fft2_U_im[0] + fft2_U_im[1] + fft2_U_im[2] + fft2_U_im[3]) : ((fft_phase2 == 1) ? fft2_U_im[1] - fft2_U_re[0] - fft2_U_im[3] + fft2_U_re[2] : ((fft_phase2 == 2) ? fft2_U_im[2] - fft2_U_im[1] + fft2_U_im[0] - fft2_U_im[3]: fft2_U_im[3] + fft2_U_re[2] - fft2_U_im[1] - fft2_U_re[0]));

    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			fft_phase2 <= 0;
			regHEAD2[0] <= 0;
			regHEAD2[1] <= 0;
			regHEAD2[2] <= 0;
			regHEAD2[3] <= 0;
			regHEAD2[4] <= 0;
			fftcount2 <= 0;
			fft2 <= 0;
			for (i = 0; i < 28; i = i + 1) begin
				stage_2[i] <= 0;
			end
		end else begin
        	if (regHEAD1[4] == 1 && regHEAD2[0] == 0 && regHEAD2[1] == 0 && regHEAD2[2] == 0 && regHEAD2[3] == 0 && regHEAD2[4] == 0) begin
            fft_phase2 <= 0;
            fftcount2 <= 1;
            regHEAD2[0] <= regHEAD1[4];
        end else begin
            if (fftcount2 == 3) begin
                fft_phase2 <= fft_phase2 + 2'd1; 
                fftcount2 <= 0;
            end else begin
                fftcount2 <= fftcount2 + 1;
            end
            if (fftcount2 == 0) begin
                regHEAD2[0] <= 0;
                regHEAD2[1] <= regHEAD2[0];
                regHEAD2[2] <= regHEAD2[1];
                regHEAD2[3] <= regHEAD2[2];
                regHEAD2[4] <= regHEAD2[3];
            end 
        end
        stage_2[27] <= fft1;
        for (i = 0; i < 27; i = i + 1) begin
            stage_2[i] <= stage_2[i + 1];
        end
        
        case (fft_phase2)
            0: begin
                fft2 <= {d2_real, d2_imag};
            end
            1: begin
                fft2 <= {(d2_real * (cos[fftcount2 * 4]) - d2_imag * (sin[fftcount2 * 4])) >>> 8, (d2_real * (sin[fftcount2 * 4]) + d2_imag * (cos[fftcount2 * 4])) >>> 8};
			end
            2: begin
                fft2 <= {(d2_real * (cos[fftcount2 * 8]) - d2_imag * (sin[fftcount2 * 8])) >>> 8, (d2_real * (sin[fftcount2 * 8]) + d2_imag * (cos[fftcount2 * 8])) >>> 8};
            end
            3:begin
                fft2 <= {(d2_real * (cos[fftcount2 * 12]) - d2_imag* (sin[fftcount2 * 12])) >>> 8, (d2_real * (sin[fftcount2 * 12]) + d2_imag * (cos[fftcount2 * 12])) >>> 8};
            end
        endcase
    	end
	end

    // stage3 //
     assign fft3_R[0] = stage_3[6];
    assign fft3_R[1] = stage_3[5];
    assign fft3_R[2] = stage_3[4];
    assign fft3_R[3] = stage_3[3];
    assign fft3_R[4] = stage_3[2];
    assign fft3_R[5] = stage_3[1];
    assign fft3_R[6] = stage_3[0];
    assign fft3_U_re[0] = fft3_R[3][63:32];
    assign fft3_U_re[1] = (fft_phase3) > 0 ? fft3_R[4][63:32] : fft3_R[0][63:32];
    assign fft3_U_re[2] = (fft_phase3) > 1 ? fft3_R[5][63:32] : fft3_R[1][63:32];
    assign fft3_U_re[3] = (fft_phase3) > 2 ? fft3_R[6][63:32] : fft3_R[2][63:32];
    assign fft3_U_im[0] = fft3_R[3][31:0];
    assign fft3_U_im[1] = (fft_phase3) > 0 ? fft3_R[4][31:0] : fft3_R[0][31:0];
    assign fft3_U_im[2] = (fft_phase3) > 1 ? fft3_R[5][31:0] : fft3_R[1][31:0];
    assign fft3_U_im[3] = (fft_phase3) > 2 ? fft3_R[6][31:0] : fft3_R[2][31:0];
    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			fft_phase3 <= 0;
			regHEAD3[0] <= 0;
			regHEAD3[1] <= 0;
			regHEAD3[2] <= 0;
			regHEAD3[3] <= 0;
			fft_out <= 0;
			for (i = 0; i < 7; i = i + 1) begin
				stage_3[i] <= 0;
			end
		end else begin
        	if (regHEAD2[4] == 1 && regHEAD3[0] == 0 && regHEAD3[1] == 0 && regHEAD3[2] == 0 && regHEAD3[3] == 0) begin
            fft_phase3 <= 2'd1;
            regHEAD3[0] <= regHEAD2[4];
            regHEAD3[1] <= regHEAD3[0];
            regHEAD3[2] <= regHEAD3[1];
            regHEAD3[3] <= regHEAD3[2];
        end else begin
            fft_phase3 <= fft_phase3 + 1;
            regHEAD3[0] <= 0;
            regHEAD3[1] <= regHEAD3[0];
            regHEAD3[2] <= regHEAD3[1];
            regHEAD3[3] <= regHEAD3[2];
        end
        
        stage_3[6] <= fft2;
        for (i = 0; i < 6; i = i + 1) begin
            stage_3[i] <= stage_3[i + 1];
        end
        case (fft_phase3)
            0: begin
                fft_out <= {fft3_U_re[0] + fft3_U_re[1] + fft3_U_re[2] + fft3_U_re[3], fft3_U_im[0] + fft3_U_im[1] + fft3_U_im[2] + fft3_U_im[3]};
            end
            1: begin
                fft_out <= {fft3_U_re[1] + fft3_U_im[0] - fft3_U_re[3] - fft3_U_im[2], fft3_U_im[1] - fft3_U_re[0] - fft3_U_im[3] + fft3_U_re[2]};
            end
            2: begin
                fft_out <= {fft3_U_re[2] - fft3_U_re[1] + fft3_U_re[0] - fft3_U_re[3], fft3_U_im[2] - fft3_U_im[1] + fft3_U_im[0] - fft3_U_im[3]};
            end
            3:begin
                fft_out <= {fft3_U_re[3] - fft3_U_im[2] - fft3_U_re[1] + fft3_U_im[0], fft3_U_im[3] + fft3_U_re[2] - fft3_U_im[1] - fft3_U_re[0]};
            end
        endcase
    	end
	end

    // reorder for fft//
	reg out_count;
    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			reorder_cnt <= 0;
			reorder_write <= 0;
			reorder_out <= 0;
			flag_in <= 0;
			rocnt <= 0;
			swap_in <= 0;
			out_count <= 0;
			REOR_HEAD <= 0;
			for (i = 0; i < 64; i = i + 1) begin
				reorder_buf[i] <= 0;
				reorder_reg[i] <= 0;
			end
		end else if (regHEAD3[3] == 1 && !swap_in) begin
            reorder_cnt <= 0;
            reorder_write <= 63;
            flag_in <= 1;
            rocnt <= 0;
            swap_in <= 1;
			out_count <= 0;
            if (flag_in) begin
                reorder_buf[reorder_cnt] <= reorder_reg[0];
                reorder_buf[reorder_cnt + 1] <= reorder_reg[16];
                reorder_buf[reorder_cnt + 2] <= reorder_reg[32];
                reorder_buf[reorder_cnt + 3] <= reorder_reg[48];
                reorder_buf[reorder_cnt + 4] <= reorder_reg[4];
                reorder_buf[reorder_cnt + 5] <= reorder_reg[20];
                reorder_buf[reorder_cnt + 6] <= reorder_reg[36];
                reorder_buf[reorder_cnt + 7] <= reorder_reg[52];
                reorder_buf[reorder_cnt + 8] <= reorder_reg[8];
                reorder_buf[reorder_cnt + 9] <= reorder_reg[24];
                reorder_buf[reorder_cnt + 10] <= reorder_reg[40];
                reorder_buf[reorder_cnt + 11] <= reorder_reg[56];
                reorder_buf[reorder_cnt + 12] <= reorder_reg[12];
                reorder_buf[reorder_cnt + 13] <= reorder_reg[28];
                reorder_buf[reorder_cnt + 14] <= reorder_reg[44];
                reorder_buf[reorder_cnt + 15] <= reorder_reg[60];
            end
        end else begin
        if (flag_in) begin
                reorder_buf[reorder_cnt] <= reorder_reg[0];
                reorder_buf[reorder_cnt + 1] <= reorder_reg[16];
                reorder_buf[reorder_cnt + 2] <= reorder_reg[32];
                reorder_buf[reorder_cnt + 3] <= reorder_reg[48];
                reorder_buf[reorder_cnt + 4] <= reorder_reg[4];
                reorder_buf[reorder_cnt + 5] <= reorder_reg[20];
                reorder_buf[reorder_cnt + 6] <= reorder_reg[36];
                reorder_buf[reorder_cnt + 7] <= reorder_reg[52];
                reorder_buf[reorder_cnt + 8] <= reorder_reg[8];
                reorder_buf[reorder_cnt + 9] <= reorder_reg[24];
                reorder_buf[reorder_cnt + 10] <= reorder_reg[40];
                reorder_buf[reorder_cnt + 11] <= reorder_reg[56];
                reorder_buf[reorder_cnt + 12] <= reorder_reg[12];
                reorder_buf[reorder_cnt + 13] <= reorder_reg[28];
                reorder_buf[reorder_cnt + 14] <= reorder_reg[44];
                reorder_buf[reorder_cnt + 15] <= reorder_reg[60];
            end
            reorder_reg[63] <= fft_out;
            for (i = 0; i < 63; i = i + 1) begin
                reorder_reg[i] <= reorder_reg[i + 1];
            end
            if (reorder_cnt == 48) begin
                reorder_cnt <= 0;
                flag_in <= 0;
            end else begin
                reorder_cnt <= reorder_cnt + 16;
            end
            reorder_write <= reorder_write + 1;
            if (reorder_write == 0 && swap_in) begin
                out_count <= 1;
                if (out_count) begin
                    REOR_HEAD <= 1;
                end else begin
                    REOR_HEAD <= 0;
                end
            end else begin
                REOR_HEAD <= 0;
            end
            if (reorder_write == 0 || reorder_write == 63) begin // shift
                reorder_out <= 0;
            end else if (reorder_write < 32)begin
                reorder_out <= reorder_buf[reorder_write - 1];
            end else begin
                reorder_out <= reorder_buf[reorder_write + 1];
            end
            //reorder_out <= reorder_buf[reorder_write];
            if (rocnt == 63) begin
                rocnt <= 0;
                reorder_cnt <= 0;
                flag_in <= 1;
            end else begin
                rocnt <= rocnt + 1;
            end
    end
	end


    // structure for ifft //
    // stage1 //
    assign ifft1_R[0] = istage_1[96];
    assign ifft1_R[1] = istage_1[80];
    assign ifft1_R[2] = istage_1[64];
    assign ifft1_R[3] = istage_1[48];
    assign ifft1_R[4] = istage_1[32];
    assign ifft1_R[5] = istage_1[16];
    assign ifft1_R[6] = istage_1[0];
    assign ifft1_U_re[0] = ifft1_R[3][63:32];
    assign ifft1_U_re[1] = (ifft_phase1) > 0 ? ifft1_R[4][63:32] : ifft1_R[0][63:32];
    assign ifft1_U_re[2] = (ifft_phase1) > 1 ? ifft1_R[5][63:32] : ifft1_R[1][63:32];
    assign ifft1_U_re[3] = (ifft_phase1) > 2 ? ifft1_R[6][63:32] : ifft1_R[2][63:32];
    assign ifft1_U_im[0] = ifft1_R[3][31:0];
    assign ifft1_U_im[1] = (ifft_phase1) > 0 ? ifft1_R[4][31:0] : ifft1_R[0][31:0];
    assign ifft1_U_im[2] = (ifft_phase1) > 1 ? ifft1_R[5][31:0] : ifft1_R[1][31:0];
    assign ifft1_U_im[3] = (ifft_phase1) > 2 ? ifft1_R[6][31:0] : ifft1_R[2][31:0];
    
   assign id1_real = (ifft_phase1 == 0) ? (ifft1_U_re[0] + ifft1_U_re[1] + ifft1_U_re[2] + ifft1_U_re[3]) : ((ifft_phase1 == 1) ? ifft1_U_re[1] + ifft1_U_im[0] - ifft1_U_re[3] - ifft1_U_im[2] : ((ifft_phase1 == 2) ? ifft1_U_re[2] - ifft1_U_re[1] + ifft1_U_re[0] - ifft1_U_re[3]: ifft1_U_re[3] - ifft1_U_im[2] - ifft1_U_re[1] + ifft1_U_im[0]));
   assign id1_imag = (ifft_phase1 == 0) ? ifft1_U_im[0] + ifft1_U_im[1] + ifft1_U_im[2] + ifft1_U_im[3] : ((ifft_phase1 == 1) ? ifft1_U_im[1] - ifft1_U_re[0] - ifft1_U_im[3] + ifft1_U_re[2] : ((ifft_phase1 == 2) ? ifft1_U_im[2] - ifft1_U_im[1] + ifft1_U_im[0] - ifft1_U_im[3] : ifft1_U_im[3] + ifft1_U_re[2] - ifft1_U_im[1] - ifft1_U_re[0]));


    always @(posedge clk or negedge NRST) begin
        if (!NRST) begin
			ifft_phase1 <= 0;
			iregHEAD1[0] <= 0;
			iregHEAD1[1] <= 0;
			iregHEAD1[2] <= 0;
			iregHEAD1[3] <= 0;
			iregHEAD1[4] <= 0;
			ifftcount1 <= 0;
			ifft1 <= 0;
			for (i = 0; i < 112; i = i + 1) begin
				istage_1[i] <= 0;
			end
		end else begin
        	if (REOR_HEAD == 1 && iregHEAD1[0] == 0 && iregHEAD1[1] == 0 && iregHEAD1[2] == 0 && iregHEAD1[3] == 0 && iregHEAD1[4] == 0) begin
            ifft_phase1 <= 0;
            iregHEAD1[0] <= REOR_HEAD;
            ifftcount1 <= 6'b1;
        end else if (ifftcount1 == 15) begin
            ifftcount1 <= 0;
            ifft_phase1 <= ifft_phase1 + 1; 
        end else if (ifftcount1 == 0) begin
            iregHEAD1[0] <= REOR_HEAD;
            iregHEAD1[1] <= iregHEAD1[0];
            iregHEAD1[2] <= iregHEAD1[1];
            iregHEAD1[3] <= iregHEAD1[2];
            iregHEAD1[4] <= iregHEAD1[3];
            ifftcount1 <= ifftcount1 + 1;
        end else begin
            ifftcount1 <= ifftcount1 + 1;
        end
        istage_1[111] <= {reorder_out[31:0], reorder_out[63:32]};
        for (i = 0; i < 111; i = i + 1) begin
            istage_1[i] <= istage_1[i + 1];
        end
        
        case (ifft_phase1)
            0: begin
                ifft1 <= {id1_real, id1_imag};
            end
            1: begin
                ifft1 <= {(id1_real * (cos[ifftcount1]) - id1_imag * (sin[ifftcount1])) >>> 8, (id1_real * (sin[ifftcount1]) + id1_imag * (cos[ifftcount1])) >>> 8};
            end
            2: begin
                ifft1 <= {(id1_real * (cos[ifftcount1 * 2]) - id1_imag * (sin[ifftcount1 * 2])) >>> 8, (id1_real * (sin[ifftcount1 * 2]) + id1_imag * (cos[ifftcount1 * 2])) >>> 8};
            end
            3:begin
                ifft1 <= {(id1_real * (cos[ifftcount1 * 3]) - id1_imag * (sin[ifftcount1 * 3])) >>> 8, (id1_real * (sin[ifftcount1 * 3]) + id1_imag * (cos[ifftcount1 * 3])) >>> 8};
            end
        endcase
    	end
	end

    // stage2 //
    assign ifft2_R[0] = istage_2[24];
    assign ifft2_R[1] = istage_2[20];
    assign ifft2_R[2] = istage_2[16];
    assign ifft2_R[3] = istage_2[12];
    assign ifft2_R[4] = istage_2[8];
    assign ifft2_R[5] = istage_2[4];
    assign ifft2_R[6] = istage_2[0];
    assign ifft2_U_re[0] = ifft2_R[3][63:32];
    assign ifft2_U_re[1] = (ifft_phase2) > 0 ? ifft2_R[4][63:32] : ifft2_R[0][63:32];
    assign ifft2_U_re[2] = (ifft_phase2) > 1 ? ifft2_R[5][63:32] : ifft2_R[1][63:32];
    assign ifft2_U_re[3] = (ifft_phase2) > 2 ? ifft2_R[6][63:32] : ifft2_R[2][63:32];
    assign ifft2_U_im[0] = ifft2_R[3][31:0];
    assign ifft2_U_im[1] = (ifft_phase2) > 0 ? ifft2_R[4][31:0] : ifft2_R[0][31:0];
    assign ifft2_U_im[2] = (ifft_phase2) > 1 ? ifft2_R[5][31:0] : ifft2_R[1][31:0];
    assign ifft2_U_im[3] = (ifft_phase2) > 2 ? ifft2_R[6][31:0] : ifft2_R[2][31:0];
    
    assign id2_real =  (ifft_phase2) == 0 ? (ifft2_U_re[0] + ifft2_U_re[1] + ifft2_U_re[2] + ifft2_U_re[3]) : ((ifft_phase2 == 1) ? ifft2_U_re[1] + ifft2_U_im[0] - ifft2_U_re[3] - ifft2_U_im[2] : ((ifft_phase2 == 2) ? ifft2_U_re[2] - ifft2_U_re[1] + ifft2_U_re[0] - ifft2_U_re[3]: ifft2_U_re[3] - ifft2_U_im[2] - ifft2_U_re[1] + ifft2_U_im[0]));

    assign id2_imag =  (ifft_phase2) == 0 ? (ifft2_U_im[0] + ifft2_U_im[1] + ifft2_U_im[2] + ifft2_U_im[3]) : ((ifft_phase2 == 1) ? ifft2_U_im[1] - ifft2_U_re[0] - ifft2_U_im[3] + ifft2_U_re[2] : ((ifft_phase2 == 2) ? ifft2_U_im[2] - ifft2_U_im[1] + ifft2_U_im[0] - ifft2_U_im[3]: ifft2_U_im[3] + ifft2_U_re[2] - ifft2_U_im[1] - ifft2_U_re[0]));

    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			ifft_phase2 <= 0;
			iregHEAD2[0] <= 0;
			iregHEAD2[1] <= 0;
			iregHEAD2[2] <= 0;
			iregHEAD2[3] <= 0;
			iregHEAD2[4] <= 0;
			ifftcount2 <= 0;
			ifft2 <= 0;
			for (i = 0; i < 28; i = i + 1) begin
				istage_2[i] <= 0;
			end
		end else begin
        	if (iregHEAD1[4] == 1 && iregHEAD2[0] == 0 && iregHEAD2[1] == 0 && iregHEAD2[2] == 0 && iregHEAD2[3] == 0 && iregHEAD2[4] == 0) begin
            ifft_phase2 <= 0;
            ifftcount2 <= 1;
            iregHEAD2[0] <= iregHEAD1[4];
        end else if (ifftcount2 == 3) begin
            ifft_phase2 <= ifft_phase2 + 1; 
            ifftcount2 <= 0;
        end else begin
            ifftcount2 <= ifftcount2 + 1;
            if (ifftcount2 == 0) begin
                iregHEAD2[0] <= 0;
                iregHEAD2[1] <= iregHEAD2[0];
                iregHEAD2[2] <= iregHEAD2[1];
                iregHEAD2[3] <= iregHEAD2[2];
                iregHEAD2[4] <= iregHEAD2[3];
            end 
        end
        istage_2[27] <= ifft1;
        for (i = 0; i < 27; i = i + 1) begin
            istage_2[i] <= istage_2[i + 1];
        end
        case (ifft_phase2)
            0: begin
                ifft2 <= {id2_real, id2_imag};
            end
            1: begin
                ifft2 <= {(id2_real * (cos[ifftcount2 * 4]) - id2_imag * (sin[ifftcount2 * 4])) >>> 8, (id2_real * (sin[ifftcount2 * 4]) + id2_imag * (cos[ifftcount2 * 4])) >>> 8};
            end
            2: begin
                ifft2 <= {(id2_real * (cos[ifftcount2 * 8]) - id2_imag * (sin[ifftcount2 * 8])) >>> 8, (id2_real * (sin[ifftcount2 * 8]) + id2_imag * (cos[ifftcount2 * 8])) >>> 8};
            end
            3:begin
                ifft2 <= {(id2_real * (cos[ifftcount2 * 12]) - id2_imag* (sin[ifftcount2 * 12])) >>> 8, (id2_real * (sin[ifftcount2 * 12]) + id2_imag * (cos[ifftcount2 * 12])) >>> 8};
            end
        endcase
    	end
	end

    // stage3 //
    assign ifft3_R[0] = istage_3[6];
    assign ifft3_R[1] = istage_3[5];
    assign ifft3_R[2] = istage_3[4];
    assign ifft3_R[3] = istage_3[3];
    assign ifft3_R[4] = istage_3[2];
    assign ifft3_R[5] = istage_3[1];
    assign ifft3_R[6] = istage_3[0];
    assign ifft3_U_re[0] = ifft3_R[3][63:32];
    assign ifft3_U_re[1] = (ifft_phase3) > 0 ? ifft3_R[4][63:32] : ifft3_R[0][63:32];
    assign ifft3_U_re[2] = (ifft_phase3) > 1 ? ifft3_R[5][63:32] : ifft3_R[1][63:32];
    assign ifft3_U_re[3] = (ifft_phase3) > 2 ? ifft3_R[6][63:32] : ifft3_R[2][63:32];
    assign ifft3_U_im[0] = ifft3_R[3][31:0];
    assign ifft3_U_im[1] = (ifft_phase3) > 0 ? ifft3_R[4][31:0] : ifft3_R[0][31:0];
    assign ifft3_U_im[2] = (ifft_phase3) > 1 ? ifft3_R[5][31:0] : ifft3_R[1][31:0];
    assign ifft3_U_im[3] = (ifft_phase3) > 2 ? ifft3_R[6][31:0] : ifft3_R[2][31:0];
    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			ifft_phase3 <= 0;
			iregHEAD3[0] <= 0;
			iregHEAD3[1] <= 0;
			iregHEAD3[2] <= 0;
			iregHEAD3[3] <= 0;
			ifft_out <= 0;
			for (i = 0; i < 7; i = i + 1) begin
				istage_3[i] <= 0;
			end
		end else begin
        	if (iregHEAD2[4] == 1 && iregHEAD3[0] == 0 && iregHEAD3[1] == 0 && iregHEAD3[2] == 0 && iregHEAD3[3] == 0) begin
            ifft_phase3 <= 1;
            iregHEAD3[0] <= iregHEAD2[4];
            iregHEAD3[1] <= iregHEAD3[0];
            iregHEAD3[2] <= iregHEAD3[1];
            iregHEAD3[3] <= iregHEAD3[2];
        end else begin
            ifft_phase3 <= ifft_phase3 + 1;
            iregHEAD3[0] <= 0;
            iregHEAD3[1] <= iregHEAD3[0];
            iregHEAD3[2] <= iregHEAD3[1];
            iregHEAD3[3] <= iregHEAD3[2];
        end
        
        istage_3[6] <= ifft2;
        for (i = 0; i < 6; i = i + 1) begin
            istage_3[i] <= istage_3[i + 1];
        end
        case (ifft_phase3)
            0: begin
                ifft_out <= {ifft3_U_re[0] + ifft3_U_re[1] + ifft3_U_re[2] + ifft3_U_re[3], ifft3_U_im[0] + ifft3_U_im[1] + ifft3_U_im[2] + ifft3_U_im[3]};
            end
            1: begin
                ifft_out <= {ifft3_U_re[1] + ifft3_U_im[0] - ifft3_U_re[3] - ifft3_U_im[2], ifft3_U_im[1] - ifft3_U_re[0] - ifft3_U_im[3] + ifft3_U_re[2]};
            end
            2: begin
                ifft_out <= {ifft3_U_re[2] - ifft3_U_re[1] + ifft3_U_re[0] - ifft3_U_re[3], ifft3_U_im[2] - ifft3_U_im[1] + ifft3_U_im[0] - ifft3_U_im[3]};
            end
            3:begin
                ifft_out <= {ifft3_U_re[3] - ifft3_U_im[2] - ifft3_U_re[1] + ifft3_U_im[0], ifft3_U_im[3] + ifft3_U_re[2] - ifft3_U_im[1] - ifft3_U_re[0]};
            end
        endcase
    	end
	end


    // reorder for ifft//
    always @(posedge clk or negedge NRST) begin
		if (!NRST) begin
			ireorder_cnt <= 0;
			ireorder_out <= 0;
			ireorder_write <= 0;
			irocnt <= 0;
			iflag_in <= 0;
			iswap_in <= 0;
			for (i = 0; i < 64; i = i + 1) begin
				ireorder_buf[i] <= 0;
				ireorder_reg[i] <= 0;
			end
		end else begin
			
        if (iregHEAD3[3] == 1 && !iswap_in) begin
            ireorder_cnt <= 0;
            ireorder_write <= 63;
            iflag_in <= 1;
            irocnt <= 0;
            iswap_in <= 1;
            if (iflag_in) begin
                ireorder_buf[ireorder_cnt] <= ireorder_reg[0];
                ireorder_buf[ireorder_cnt + 1] <= ireorder_reg[16];
                ireorder_buf[ireorder_cnt + 2] <= ireorder_reg[32];
                ireorder_buf[ireorder_cnt + 3] <= ireorder_reg[48];
                ireorder_buf[ireorder_cnt + 4] <= ireorder_reg[4];
                ireorder_buf[ireorder_cnt + 5] <= ireorder_reg[20];
                ireorder_buf[ireorder_cnt + 6] <= ireorder_reg[36];
                ireorder_buf[ireorder_cnt + 7] <= ireorder_reg[52];
                ireorder_buf[ireorder_cnt + 8] <= ireorder_reg[8];
                ireorder_buf[ireorder_cnt + 9] <= ireorder_reg[24];
                ireorder_buf[ireorder_cnt + 10] <= ireorder_reg[40];
                ireorder_buf[ireorder_cnt + 11] <= ireorder_reg[56];
                ireorder_buf[ireorder_cnt + 12] <= ireorder_reg[12];
                ireorder_buf[ireorder_cnt + 13] <= ireorder_reg[28];
                ireorder_buf[ireorder_cnt + 14] <= ireorder_reg[44];
                ireorder_buf[ireorder_cnt + 15] <= ireorder_reg[60];
            end
        end else begin
            if (iflag_in) begin
                ireorder_buf[ireorder_cnt] <= ireorder_reg[0];
                ireorder_buf[ireorder_cnt + 1] <= ireorder_reg[16];
                ireorder_buf[ireorder_cnt + 2] <= ireorder_reg[32];
                ireorder_buf[ireorder_cnt + 3] <= ireorder_reg[48];
                ireorder_buf[ireorder_cnt + 4] <= ireorder_reg[4];
                ireorder_buf[ireorder_cnt + 5] <= ireorder_reg[20];
                ireorder_buf[ireorder_cnt + 6] <= ireorder_reg[36];
                ireorder_buf[ireorder_cnt + 7] <= ireorder_reg[52];
                ireorder_buf[ireorder_cnt + 8] <= ireorder_reg[8];
                ireorder_buf[ireorder_cnt + 9] <= ireorder_reg[24];
                ireorder_buf[ireorder_cnt + 10] <= ireorder_reg[40];
                ireorder_buf[ireorder_cnt + 11] <= ireorder_reg[56];
                ireorder_buf[ireorder_cnt + 12] <= ireorder_reg[12];
                ireorder_buf[ireorder_cnt + 13] <= ireorder_reg[28];
                ireorder_buf[ireorder_cnt + 14] <= ireorder_reg[44];
                ireorder_buf[ireorder_cnt + 15] <= ireorder_reg[60];
            end
            ireorder_reg[63] <= ifft_out;
            for (i = 0; i < 63; i = i + 1) begin
                ireorder_reg[i] <= ireorder_reg[i + 1];
            end
            if (ireorder_cnt == 48) begin
                ireorder_cnt <= 0;
                iflag_in <= 0;
            end else begin
                ireorder_cnt <= ireorder_cnt + 16;
            end
            ireorder_write <= ireorder_write + 1;
            if (ireorder_write == 0) begin
                OUT_HEAD <= 1;
            end else begin
                OUT_HEAD <= 0;
            end
                
            ireorder_out <= ireorder_buf[ireorder_write];
            if (irocnt == 63) begin
                irocnt <= 0;
                iflag_in <= 1;
            end else begin
                irocnt <= irocnt + 1;
            end
        end
    end
	end


   // key trigger
   keytr			u3(
				   .clock(CLK_1M),
				   .key0(KEY[1]),
				   .rst_n(NRST),
				   .KEY0_EDGE(KEY0_EDGE)
				   );
   
   //I2C output data
   CLOCK_500		u1(
			   .CLOCK(CLOCK_50),
			   .rst_n(NRST),					 
			   .sel(KEY[2]), .state(LEDR[1:0]),
			   .END(END),
			   .KEY0_EDGE(KEY0_EDGE),
			   
			   .CLOCK_500(CLK_1M),
			   .GO(GO),             
			   .CLOCK_2(AUD_XCK),
			   .DATA(AUD_I2C_DATA)
			   );
   
   //i2c controller
   i2c				u2( 
				    // Host Side
				    .CLOCK(CLK_1M),
				    .RESET(1'b1),
				    // I2C Side
				    .I2C_SDAT(FPGA_I2C_SDAT),
				    .I2C_DATA(AUD_I2C_DATA),
				    .I2C_SCLK(FPGA_I2C_SCLK),
				    // Control Signals
				    .GO(GO),
				    .END(END)
				    );

endmodule 

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/07 22:17:28
// Module Name: tb_sdram_ctrl
// Description: testbench for sdram_ctrl module
//////////////////////////////////////////////////////////////////////////////////


module tb_sdram_ctrl(

    );
    reg          clk             ;
    wire         clk_100M        ;
    wire         clk_100M_shift  ;
    wire         clk_50M         ;
    wire         locked          ;
    reg          rst_n           ;
    
    //复位信号与锁定信号相与,表示真正有效的复位
    wire         locked_rst_n    ;   
    
    
    //sdram_ctrl模块输入输出连线
    reg         rd_req           ;
    reg  [23:0] rd_addr          ;
    wire [9:0]  rd_burst_len     ;

    reg         wr_req           ;
    reg  [23:0] wr_addr          ;
    reg  [15:0] wr_data          ;
    wire [9:0]  wr_burst_len     ;

    wire        rd_ack           ;
    wire        wr_ack           ;

    wire        cke              ;
    wire        sdram_cs_n       ;
    wire        sdram_ras_n      ;
    wire        sdram_cas_n      ;
    wire        sdram_we_n       ;
    wire [1:0]  sdram_ba         ;
    wire [12:0] sdram_addr       ;
    wire [15:0] sdram_dq         ;

    wire [15:0] rd_data          ;
    
    //clk_gen模块的复位信号高电平有效
    assign reset = ~rst_n;
    
    //复位信号与锁定信号相与
    assign locked_rst_n = rst_n & locked;
    
    integer i;
    //系统时钟和复位
    initial begin
        clk = 1'b1;
        rst_n <= 1'b0;
        wr_req <= 1'b0;
        rd_req <= 1'b0;
    #20
        rst_n <= 1'b1;
        wr_req <= 1'b1;
    #60
        wr_req <= 1'b0;
    #203_000
    
    //连续进行读写操作
    for(i=0;i<2022;i=i+1) begin
        #10_000
            wr_req <= 1'b1;  //写请求
        #60 
            wr_req <= 1'b0;
        #10_000
            rd_req <= 1'b1;  //读请求
        #80
            rd_req <= 1'b0;
    
    end
    end
    
    always#10 clk = ~clk;    
    
    //重定义sdram仿真模型参数
    defparam sdram_model_plus_init.addr_bits = 13;
    defparam sdram_model_plus_init.data_bits = 16;
    defparam sdram_model_plus_init.col_bits = 9;
    defparam sdram_model_plus_init.mem_sizes = 2*1024*1024;

    //潜伏期重配置, CAS要保持一致
    defparam sdram_ctrl_inst.sdram_init_inst.CAS = 3'b011;
    defparam sdram_ctrl_inst.sdram_read_inst.CAS = 3'b011;
    
    //读写地址
    //wr_addr
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!rst_n) begin
            wr_addr <= 24'h000000;
        end else if(wr_ack) begin
            //每次突发传输只实际写入一个首地址, 更新地址可以得到下一次突发传输的首地址
            wr_addr <= wr_addr + 24'd1;  
        end else begin
            wr_addr <= wr_addr;
        end
    end
    
    //rd_addr
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!rst_n) begin
            rd_addr <= 24'h000000;
        end else if(rd_ack) begin
            //每次突发传输只实际写入一个首地址, 更新地址可以得到下一次突发传输的首地址
            rd_addr <= rd_addr + 24'd1;  
        end else begin
            rd_addr <= rd_addr;
        end
    end   
    
    
    //读写突发长度
    assign wr_burst_len = 10'd10;
    assign rd_burst_len = 10'd10;
    
    //更新写入的数据wr_data
    always@(posedge clk_100M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            wr_data <= 16'd0;
        end else if(wr_ack) begin
            wr_data <= wr_data + 16'd1;
        end else begin
            wr_data <= wr_data;
        end
    end
    
    
    //时钟生成IP核
      clk_gen clk_gen_inst
   (
        // Clock out ports
        .clk_50M(clk_50M),     
        .clk_100M(clk_100M),     
        .clk_100M_shift(clk_100M_shift),    
        // Status and control signals
        .reset(reset), 
        .locked(locked),       
        // Clock in ports
        .clk_in1(clk)  //50M时钟输入
    
    );

    //sdram仿真模块
    sdram_model_plus sdram_model_plus_init
    (
        .Dq      (sdram_dq          ),  
        .Addr    (sdram_addr        ),  
        .Ba      (sdram_ba          ), 
        .Clk     (clk_100M_shift    ),   //使用有相位偏移的时钟
        .Cke     (cke               ), 
        .Cs_n    (sdram_cs_n        ), 
        .Ras_n   (sdram_ras_n       ), 
        .Cas_n   (sdram_cas_n       ), 
        .We_n    (sdram_we_n        ), 
        .Dqm     (2'b00             ),  //相当于不使用掩码
        .Debug   (1'b1              )
    );  
    
    
    //sdram_ctrl模块例化
    sdram_ctrl sdram_ctrl_inst(
        .clk             (clk_100M        ),
        .rst_n           (locked_rst_n    ),

        .rd_req          (rd_req          ), 
        .rd_addr         (rd_addr         ), 
        .rd_burst_len    (rd_burst_len    ),

        .wr_req          (wr_req          ), 
        .wr_addr         (wr_addr         ), 
        .wr_data         (wr_data         ),
        .wr_burst_len    (wr_burst_len    ),

        .rd_ack          (rd_ack          ), 
        .wr_ack          (wr_ack          ),  

        .cke             (cke             ),   
        .sdram_cs_n      (sdram_cs_n      ),
        .sdram_ras_n     (sdram_ras_n     ),
        .sdram_cas_n     (sdram_cas_n     ),
        .sdram_we_n      (sdram_we_n      ),
        .sdram_ba        (sdram_ba        ),
        .sdram_addr      (sdram_addr      ),        
        .sdram_dq        (sdram_dq        ),  

        .rd_data         (rd_data         )   
    );
endmodule

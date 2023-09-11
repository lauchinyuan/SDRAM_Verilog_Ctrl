`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/10 19:24:51
// Module Name: tb_sdram_interface
// Description: testbench for sdram_interface module
//////////////////////////////////////////////////////////////////////////////////


module tb_sdram_interface(

    );

    //重定义sdram仿真模型参数
    defparam sdram_model_plus_init.addr_bits = 13;
    defparam sdram_model_plus_init.data_bits = 16;
    defparam sdram_model_plus_init.col_bits = 9;
    defparam sdram_model_plus_init.mem_sizes = 2*1024*1024;
    
    
    //基本外部时钟及复位信号
    reg         clk                 ;
    reg         rst_n               ;
    wire        clk_100M            ;
    wire        clk_100M_shift      ;
    wire        clk_50M             ;
    wire        locked              ;
    wire        reset               ;
    

    //系统时钟(50M)和复位
    initial begin
        clk = 1'b1          ;
        rst_n <= 1'b0       ;
    #20
        rst_n <= 1'b1       ;
    end
    
    //系统时钟
    always#10 clk = ~clk    ;
    


    //复位信号与锁定信号相与,产生真正有效的系统复位
    wire   locked_rst_n             ;     
    
    //数据端口及中间连线
    //写操作
    wire        wr_rst              ;
    wire        fifo_wr_req         ;
    reg  [15:0] fifo_wr_data        ;
    wire [23:0] sdram_wr_beg_addr   ;  //写SDRAM的起始地址
    wire [23:0] sdram_wr_end_addr   ;  //终止地址
    wire [9:0]  wr_burst_len        ;
    wire        sdram_clk_o         ;
    wire        fifo_wr_rst_busy    ;  //写FIFO初始化忙碌
    
    //读操作                        
    wire        rd_rst              ;
    reg         fifo_rd_req         ;
    wire [15:0] fifo_rd_data        ;  //从FIFO中读取的数据,向外界输出
    wire [23:0] sdram_rd_beg_addr   ;  //写SDRAM的起始地址
    wire [23:0] sdram_rd_end_addr   ;  //终止地址
    wire [9:0]  rd_burst_len        ;  
    reg         sdram_rd_valid      ;  //SDRAM写有效信号
    wire [9:0]  rd_fifo_cnt         ;
                                    
    //模块与SDRAM仿真模型之间的交互总线     
    wire        cke                 ;  //SDRAM时钟使能  
    wire        sdram_cs_n          ;
    wire        sdram_ras_n         ;
    wire        sdram_cas_n         ;
    wire        sdram_we_n          ;
    wire [1:0]  sdram_ba            ;
    wire [12:0] sdram_addr          ;        
    wire [15:0] sdram_dq            ;  //读写SDRAM的数据总线
    
    //其他辅助信号
    reg [2:0]   cnt_wr_wait         ;  //写等待计数器, 用于定期产生FIFO写数据和写请求信号
    reg         wr_flag             ;  //写数据标志信号, 用于定期产生FIFO写数据和写请求信号
    reg         fifo_wr_en          ;  //FIFO写数据定时更新使能
    reg [9:0]   cnt_rd              ;  //从FIFO中读取的数据的个数统计
    reg         fifo_wr_en_d        ;  //fifo_wr_en打拍
    wire        fifo_wr_en_fall     ;  //fifo_wr_en下降沿
    
    
    assign locked_rst_n = rst_n & locked;   
    //clk_gen模块的复位信号高电平有效
    assign reset = ~rst_n;
    
    
    //定期产生FIFO写数据和写请求信号
    
    //fifo_wr_en
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin  
            fifo_wr_en <= 1'b0;
        end else if(fifo_wr_data == 16'd30) begin  //写入30个数据为例
            fifo_wr_en <= 1'b0;
        end else if(!fifo_wr_rst_busy) begin  //写FIFO初始化完成
            fifo_wr_en <= 1'b1;
        end else begin
            fifo_wr_en <= fifo_wr_en;
        end
    end
    
    //写等待计数器
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            cnt_wr_wait <= 3'd0;
        end else if(fifo_wr_en) begin
            cnt_wr_wait <= cnt_wr_wait + 3'd1;
        end else begin
            cnt_wr_wait <= 3'd0;
        end
    end
    
    //wr_flag,定时产生,起始就是FIFO写请求信号(fifo_wr_req)
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            wr_flag <= 1'b0;
        end else if(cnt_wr_wait == 3'd7) begin
            wr_flag <= 1'b1;
        end else begin
            wr_flag <= 1'b0;
        end
    end
    
    assign fifo_wr_req = wr_flag;
    
    //fifo_wr_data
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            fifo_wr_data <= 16'b0;
        end else if(wr_flag) begin
            fifo_wr_data <= fifo_wr_data + 16'd1;
        end else begin
            fifo_wr_data <= fifo_wr_data;
        end
    end
    
    
    //产生读请求信号以及读SDRAM有效信号
    //fifo_rd_req
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            fifo_rd_req <= 1'b0;
        end else if(cnt_rd == 10'd9) begin //已经读了10个数据
            fifo_rd_req <= 1'b0;
        end else if(rd_fifo_cnt >= 10'd10) begin //FIFO中有了足够数据
            fifo_rd_req <= 1'b1;
        end else begin
            fifo_rd_req <= fifo_rd_req;
        end
    end
    
    //cnt_rd
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            cnt_rd <= 10'd0;
        end else if(cnt_rd == 10'd9) begin
            cnt_rd <= 10'd0;
        end else if(fifo_rd_req) begin
            cnt_rd <= cnt_rd + 10'd1;
        end else begin
            cnt_rd <= cnt_rd;
        end
    end
    
    //fifo_wr_en打拍,用于产生下降沿标志
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            fifo_wr_en_d <= 1'b0;
        end else begin
            fifo_wr_en_d <= fifo_wr_en;
        end
    end
    
    //fifo_wr_req下降沿标志,标志一次写入完成,可以进行有效的FIFO读取了
    assign fifo_wr_en_fall = (fifo_wr_en_d==1'b1 && fifo_wr_en == 1'b0)?1'b1:1'b0;
    
    //sdram_rd_valid, 需要在写完成之后使其有效, 且当读FIFO有足够数据时使之无效
    always@(posedge clk_50M or negedge locked_rst_n) begin
        if(!locked_rst_n) begin
            sdram_rd_valid <= 1'b0;
        end else if(rd_fifo_cnt == 10'd10) begin  //读FIFO中已经有10个数据,可以暂时不读
            sdram_rd_valid <= 1'b0;
        end else if(fifo_wr_en_fall) begin  //写请求下降沿,说明已经写入了数据,可以发起读请求
            sdram_rd_valid <= 1'b1;
        end
    end
    
    //读写起始地址、突发长度
    assign sdram_wr_beg_addr = 24'd0;
    assign sdram_wr_end_addr = 24'd19;
    assign sdram_rd_beg_addr = 24'd0;
    assign sdram_rd_end_addr = 24'd10;
    assign wr_burst_len = 10'd10;
    assign rd_burst_len = 10'd10;
    
    //读写复位
    assign wr_rst = ~locked_rst_n;
    assign rd_rst = ~locked_rst_n;
    
    
    //时钟生成IP核
    clk_gen clk_gen_inst
   (
        // Clock out ports
        .clk_50M(clk_50M),     
        .clk_100M(clk_100M),     
        .clk_100M_shift(clk_100M_shift),  //带相位偏移的100M时钟  
        .reset(reset), 
        .locked(locked),       

        .clk_in1(clk)  //50M时钟输入
    ); 
    
    
    
    //sdram接口模块
    sdram_interface sdram_interface_inst(
        .clk                 (clk_100M            ),  //SDRAM读写接口使用100M时钟
        .rst_n               (locked_rst_n        ),
        .fifo_wr_clk         (clk_50M             ),  //读写FIFO使用50M时钟
        .fifo_rd_clk         (clk_50M             ),
        .sdram_clk_i         (clk_100M_shift      ),  //给SDRAM提供100M相位偏移时钟
        .sdram_clk_o         (sdram_clk_o         ), 
                              
        .wr_rst              (wr_rst              ),
        .fifo_wr_req         (fifo_wr_req         ),
        .fifo_wr_data        (fifo_wr_data        ),
        .sdram_wr_beg_addr   (sdram_wr_beg_addr   ),  //写SDRAM的起始地址
        .sdram_wr_end_addr   (sdram_wr_end_addr   ),  //终止地址
        .wr_burst_len        (wr_burst_len        ),  
        .fifo_wr_rst_busy    (fifo_wr_rst_busy    ),
                              
        .rd_rst              (rd_rst              ),
        .fifo_rd_req         (fifo_rd_req         ),
        .fifo_rd_data        (fifo_rd_data        ),  //从FIFO中读取的数据,向外界输出
        .sdram_rd_beg_addr   (sdram_rd_beg_addr   ),  //读SDRAM的起始地址
        .sdram_rd_end_addr   (sdram_rd_end_addr   ),  //终止地址
        .rd_burst_len        (rd_burst_len        ),  
        .sdram_rd_valid      (sdram_rd_valid      ),  //SDRAM读有效信号
        .rd_fifo_cnt         (rd_fifo_cnt         ),
                              
        .cke                 (cke                 ),  //SDRAM时钟使能  
        .sdram_cs_n          (sdram_cs_n          ),
        .sdram_ras_n         (sdram_ras_n         ),
        .sdram_cas_n         (sdram_cas_n         ),
        .sdram_we_n          (sdram_we_n          ),
        .sdram_ba            (sdram_ba            ),
        .sdram_addr          (sdram_addr          ),        
        .sdram_dq            (sdram_dq            )   //读写SDRAM的数据总线
        
    );
    
    //sdram仿真模块
    sdram_model_plus sdram_model_plus_init
    (
        .Dq      (sdram_dq              ),  
        .Addr    (sdram_addr            ),  
        .Ba      (sdram_ba              ), 
        .Clk     (sdram_clk_o           ),   
        .Cke     (cke                   ), 
        .Cs_n    (sdram_cs_n            ), 
        .Ras_n   (sdram_ras_n           ), 
        .Cas_n   (sdram_cas_n           ), 
        .We_n    (sdram_we_n            ), 
        .Dqm     (2'b00                 ),  //相当于不使用掩码
        .Debug   (1'b1                  )
    );   
    
    
endmodule

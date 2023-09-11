`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/10 18:41:07
// Module Name: sdram_interface
// Description: SDRAM读写接口,集成读写FIFO以及SDRAM控制器
//////////////////////////////////////////////////////////////////////////////////

module sdram_interface(
        input   wire        clk                 ,
        input   wire        rst_n               ,
        input   wire        fifo_wr_clk         ,
        input   wire        fifo_rd_clk         ,
        input   wire        sdram_clk_i         , //提供给SDRAM的时钟

        //写操作
        input   wire        wr_rst              ,
        input   wire        fifo_wr_req         ,
        input   wire [15:0] fifo_wr_data        ,
        input   wire [23:0] sdram_wr_beg_addr   ,  //写SDRAM的起始地址
        input   wire [23:0] sdram_wr_end_addr   ,  //终止地址
        input   wire [9:0]  wr_burst_len        , 
        output  wire        fifo_wr_rst_busy    ,  //写FIFO复位忙碌信号

        //读操作
        input   wire        rd_rst              ,
        input   wire        fifo_rd_req         ,
        output  wire [15:0] fifo_rd_data        ,  //从FIFO中读取的数据,向外界输出
        input   wire [23:0] sdram_rd_beg_addr   ,  //写SDRAM的起始地址
        input   wire [23:0] sdram_rd_end_addr   ,  //终止地址
        input   wire [9:0]  rd_burst_len        ,  
        input   wire        sdram_rd_valid      ,  //SDRAM写有效信号
        output  wire [9:0]  rd_fifo_cnt         ,

        //模块与SDRAM之间的交互总线
        output  wire        sdram_clk_o         ,
        output  wire        cke                 ,  //SDRAM时钟使能  
        output  wire        sdram_cs_n          ,
        output  wire        sdram_ras_n         ,
        output  wire        sdram_cas_n         ,
        output  wire        sdram_we_n          ,
        output  wire [1:0]  sdram_ba            ,
        output  wire [12:0] sdram_addr          ,        
        inout   wire [15:0] sdram_dq               //读写SDRAM的数据总线
        
    );
    
    //SDRAM控制器和FIFO控制器的连线
    wire        sdram_rd_req        ;
    wire        sdram_rd_ack        ;
    wire [23:0] sdram_rd_addr       ;
    wire [15:0] sdram_rd_data       ;
    
    wire        sdram_wr_req        ;
    wire        sdram_wr_ack        ;
    wire [23:0] sdram_wr_addr       ;
    wire [15:0] sdram_wr_data       ;
    
    
    //sdram控制器
    sdram_ctrl sdram_ctrl_inst(
        .clk             (clk             ),
        .rst_n           (rst_n           ),
                          
        .rd_req          (sdram_rd_req    ), //读请求
        .rd_addr         (sdram_rd_addr   ), //读地址, 2bit Bank_addr + 13bit Row_addr + 9bit Column_addr
        .rd_burst_len    (rd_burst_len    ),
        .rd_data         (sdram_rd_data   ), //从SDRAM中读到的数据
                          
        .wr_req          (sdram_wr_req    ), 
        .wr_addr         (sdram_wr_addr   ), 
        .wr_data         (sdram_wr_data   ),
        .wr_burst_len    (wr_burst_len    ),
                          
        .rd_ack          (sdram_rd_ack    ), //rd_ack与有效读出数据对齐
        .wr_ack          (sdram_wr_ack    ), //wr_ack相对写入数据提前一个时钟周期拉高,以告知外部模块更新数据 
                          
        .cke             (cke             ), //SDRAM时钟使能  
        .sdram_cs_n      (sdram_cs_n      ),
        .sdram_ras_n     (sdram_ras_n     ),
        .sdram_cas_n     (sdram_cas_n     ),
        .sdram_we_n      (sdram_we_n      ),
        .sdram_ba        (sdram_ba        ),
        .sdram_addr      (sdram_addr      ),        
        .sdram_dq        (sdram_dq        )  //读写SDRAM的数据总线
        
        
    );
    
    
    //FIFO控制模块
    fifo_ctrl fifo_ctrl_inst(
        .clk                 (clk                 ),
        .rst_n               (rst_n               ),
        //fifo_write模块        
        .wr_rst              (wr_rst              ),  //写复位
        .fifo_wr_clk         (fifo_wr_clk         ),
        .fifo_wr_req         (fifo_wr_req         ),
        .fifo_wr_data        (fifo_wr_data        ),
        .sdram_wr_beg_addr   (sdram_wr_beg_addr   ),  //写SDRAM的起始地址
        .sdram_wr_end_addr   (sdram_wr_end_addr   ),  //终止地址
        .wr_burst_len        (wr_burst_len        ),  
        .sdram_wr_ack        (sdram_wr_ack        ),  //sdram_ctrl模块发出的写响应信号
        .sdram_wr_req        (sdram_wr_req        ),  //向SDRAM控制器发送写SDRAM请求
        .sdram_wr_addr       (sdram_wr_addr       ),  //发送到SDRAM控制模块
        .sdram_wr_data       (sdram_wr_data       ),  //发送到SDRAM控制模块
        .fifo_wr_rst_busy    (fifo_wr_rst_busy    ),  //写FIFO复位忙碌信号,只有当该信号为低电平,写FIFO才能进行写入
        //fifo_read模块      
        .rd_rst              (rd_rst              ),
        .fifo_rd_clk         (fifo_rd_clk         ),
        .fifo_rd_req         (fifo_rd_req         ),
        .fifo_rd_data        (fifo_rd_data        ),  //从FIFO中读取的数据,向外界输出
        .sdram_rd_beg_addr   (sdram_rd_beg_addr   ),  //读SDRAM的起始地址
        .sdram_rd_end_addr   (sdram_rd_end_addr   ),  //终止地址
        .rd_burst_len        (rd_burst_len        ), 
        .sdram_rd_valid      (sdram_rd_valid      ),  //SDRAM读有效信号,该信号为高电平时才能进行读SDRAM操作
        .sdram_rd_ack        (sdram_rd_ack        ),  //sdram_ctrl模块发出的读响应信号        
        .sdram_rd_req        (sdram_rd_req        ),  //向SDRAM控制器发送读SDRAM请求
        .sdram_rd_addr       (sdram_rd_addr       ),
        .sdram_rd_data       (sdram_rd_data       ),
        .rd_fifo_cnt         (rd_fifo_cnt         )   //读FIFO数据个数
    );
    
    //SDRAM时钟直接传给SDRAM即可
    assign sdram_clk_o = sdram_clk_i    ;
    
    
endmodule

`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/11 21:07:33
// Module Name: uart_sdram_top
// Description: 顶层模块,集成SDRAM接口、RS232串口收发器及串口读FIFO,实现将RS232串口数据读写到SDRAM中
//////////////////////////////////////////////////////////////////////////////////


module uart_sdram_top(
        input   wire        clk                 ,  //50MHz时钟
        input   wire        rst_n               ,

        //RS232串口
        input   wire        rx                  ,
        output  wire        tx                  ,
        
        //SDRAM写
        input   wire [23:0] sdram_wr_beg_addr   , //SDRAM写起始地址
        input   wire [23:0] sdram_wr_end_addr   , //SDRAM写起始地址
        input   wire [9:0]  wr_burst_len        , //SDRAM写突发长度

        //SDRAM读
        input   wire [23:0] sdram_rd_beg_addr   , //SDRAM读起始地址
        input   wire [23:0] sdram_rd_end_addr   , //SDRAM读起始地址
        input   wire [9:0]  rd_burst_len        , //SDRAM读突发长度 
        input   wire        sdram_rd_valid      , //SDRAM读有效信号
        

        //SDRAM物理接口
        output  wire        sdram_clk           ,
        output  wire        cke                 ,  //SDRAM时钟使能  
        output  wire        sdram_cs_n          ,
        output  wire        sdram_ras_n         ,
        output  wire        sdram_cas_n         ,
        output  wire        sdram_we_n          ,
        output  wire [1:0]  sdram_ba            ,
        output  wire [12:0] sdram_addr          ,        
        inout   wire [15:0] sdram_dq            ,  //读写SDRAM的数据总线  
        output  wire [1:0]  sdram_dqm           
    );
    
    //模块间连线
    //串口
    wire [7:0]  tx_data             ;
    wire [7:0]  rx_data             ;
    wire        tx_flag             ;
    wire        rx_flag             ;
    
    //时钟生成IP核
    wire        clk_100M            ;
    wire        clk_100M_shift      ;
    wire        clk_50M             ;
    wire        locked              ;
    wire        reset               ;
    wire        locked_rst_n        ;
    
    //SDRAM接口与UART读FIFO
    wire [9:0]  rd_fifo_cnt         ;
    wire [15:0] fifo_rd_data        ;
    wire        fifo_rd_req         ;
    
    
    //时钟生成IP核
    clk_gen clk_gen_inst
   (
        // Clock out ports
        .clk_50M            (clk_50M        ),     
        .clk_100M           (clk_100M       ),     
        .clk_100M_shift     (clk_100M_shift ),  
        .reset              (~rst_n         ), 
        .locked             (locked         ),       

        .clk_in1            (clk            )  //50M时钟输入
    ); 
    
    assign locked_rst_n = locked & rst_n;
    
   
    
    
    
    
    //SDRAM接口模块
    sdram_interface sdram_interface_inst(
        .clk                 (clk_100M            ),
        .rst_n               (locked_rst_n        ),
        .fifo_wr_clk         (clk_50M             ),
        .fifo_rd_clk         (clk_50M             ),
        .sdram_clk_i         (clk_100M_shift      ), //提供给SDRAM的时钟,是带相位偏移的100M时钟

        //写操作
        .wr_rst              (~locked_rst_n       ),
        .fifo_wr_req         (rx_flag             ), //rx_flag高电平,代表串口接收到有效的数据,同时拉高FIFO写请求
        .fifo_wr_data        ({8'b0,rx_data}      ), //写入写FIFO的数据是rx_data
        .sdram_wr_beg_addr   (sdram_wr_beg_addr   ), //写SDRAM的起始地址
        .sdram_wr_end_addr   (sdram_wr_end_addr   ), //终止地址
        .wr_burst_len        (wr_burst_len        ), 
        .fifo_wr_rst_busy    (                    ),  

        //读操作
        .rd_rst              (~locked_rst_n       ),
        .fifo_rd_req         (fifo_rd_req         ),
        .fifo_rd_data        (fifo_rd_data        ),  //从FIFO中读取的数据,向外界输出
        .sdram_rd_beg_addr   (sdram_rd_beg_addr   ),  //写SDRAM的起始地址
        .sdram_rd_end_addr   (sdram_rd_end_addr   ),  //终止地址
        .rd_burst_len        (rd_burst_len        ),  
        .sdram_rd_valid      (sdram_rd_valid      ),  //SDRAM读有效信号
        .rd_fifo_cnt         (rd_fifo_cnt         ),

        //模块与SDRAM之间的交互总线
        .sdram_clk_o         (sdram_clk           ),
        .cke                 (cke                 ),  //SDRAM时钟使能  
        .sdram_cs_n          (sdram_cs_n          ),
        .sdram_ras_n         (sdram_ras_n         ),
        .sdram_cas_n         (sdram_cas_n         ),
        .sdram_we_n          (sdram_we_n          ),
        .sdram_ba            (sdram_ba            ),
        .sdram_addr          (sdram_addr          ),        
        .sdram_dq            (sdram_dq            ),   //读写SDRAM的数据总线
        .sdram_dqm           (sdram_dqm           )
        
    );
    
    uart_rd_fifo uart_rd_fifo_inst(
        .clk                 (clk_50M             ),
        .rst_n               (locked_rst_n        ),
        .sdram_rd_fifo_cnt   (rd_fifo_cnt         ), //SDRAM接口模块内部读FIFO的数据个数
        .fifo_rd_data        (fifo_rd_data[7:0]   ), //SDRAM接口模块读FIFO读出的数据
        .burst_len           (rd_burst_len        ), //突发传输长度

        .sdram_fifo_rd_en    (fifo_rd_req         ), //SDRAM 读FIFO读取请求
        .tx_data             (tx_data             ), //输出到串口的数据(FIFO读出)
        .tx_flag             (tx_flag             )  //串口数据传输标志
    );
    
    
    
    uart_rx 
    #(
        .UART_BPS('d9600      ),    //串口波特率
        .CLK_FREQ('d50_000_000)     //时钟频率
    ) uart_rx_inst
    (
        .sys_clk     (clk_50M       ),   
        .sys_rst_n   (locked_rst_n  ),   
        .rx          (rx            ),   //串口接收数据

        .po_data     (rx_data       ),   //串转并后的8bit数据
        .po_flag     (rx_flag       )    //串转并后的数据有效标志信号
    );
    
    
    //RS232串口TX模块
    uart_tx 
    #(
        .UART_BPS('d9600        ),     //串口波特率
        .CLK_FREQ('d50_000_000  )      //时钟频率
    ) uart_tx_inst
    (
        .sys_clk     (clk_50M       ),   //系统时钟50MHz
        .sys_rst_n   (locked_rst_n  ),   //全局复位
        .pi_data     (tx_data       ),   //模块输入的8bit数据
        .pi_flag     (tx_flag       ),   //并行数据有效标志信号

        .tx          (tx            )    //串转并后的1bit数据
    );
    
endmodule

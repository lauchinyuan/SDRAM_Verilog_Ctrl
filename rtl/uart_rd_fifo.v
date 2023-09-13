`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: lauchinyuan
// Email: lauchinyuan@yeah.net
// Create Date: 2023/09/11 15:34:24
// Module Name: uart_rd_fifo
// Description: 串口读FIFO控制模块,从SDRAM读FIFO中高速读出的数据,暂存在此模块FIFO中,通过串口低速读出
// 模块控制逻辑会依据串口速率进行定时,逐步读取本地FIFO中缓存的数据,以实现读写速率变换
//////////////////////////////////////////////////////////////////////////////////
module uart_rd_fifo(
        input   wire        clk                 ,
        input   wire        rst_n               ,
        input   wire [9:0]  sdram_rd_fifo_cnt   , //SDRAM接口模块内部读FIFO的数据个数
        input   wire [7:0]  fifo_rd_data        , //SDRAM接口模块读FIFO读出的数据
        input   wire [9:0]  burst_len           , //突发传输长度
        
        output  reg         sdram_fifo_rd_en    , //SDRAM 读FIFO读取请求
        output  wire [7:0]  tx_data             , //输出到串口的数据(FIFO读出)
        output  reg         tx_flag               //串口数据传输标志
    );
    
    //参数定义
    parameter   BAUD_CNT_MAX    =       13'd5207,   //串口波特率计数器的计数最大值,也就是串口协议收发每一bit所用的时钟周期
                BAUD_CNT_HALF   =       13'd2603;   //串口波特率计数器的计数中间值
    
    //中间变量
    reg         sdram_fifo_rd_en_d      ; //sdram_fifo_rd_en打拍,与有效数据对齐,用于本地FIFO的写请求
    wire        sdram_fifo_rd_en_fall   ; //sdram_fifo_rd_en下降沿标志,表示这一时刻的sdram_rd_fifo_cnt并不是真实数据个数,还需要等待递减完成
    wire[9:0]   data_num                ; //本地FIFO数据个数
    reg [9:0]   cnt_data                ; //sdram_fifo_rd_en持续时间计数器(持续一个burst_len长度)
    reg         rd_flag                 ; //本地FIFO有效读取标志,高电平时开始进行计时(和串口波特率匹配),并逐步读取一个burst_len长度的数据
    reg [12:0]  cnt_baud                ; //波特率计数器,用于定时,匹配串口速率
    reg         bit_flag                ; //波特率计数器中间时刻标志
    reg [3:0]   bit_cnt                 ; //串口发送比特计数器
    reg         read_fifo_en            ; //读本地FIFO请求
    reg [9:0]   local_fifo_cnt_read     ; //本地FIFO读取个数计数器
    
    assign sdram_fifo_rd_en_fall = (sdram_fifo_rd_en_d == 1'b1 && sdram_fifo_rd_en == 1'b0)?1'b1:1'b0;
    
    //cnt_data
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_data <= 10'd0;
        end else if(sdram_fifo_rd_en && cnt_data == burst_len - 10'd1) begin
            cnt_data <= 10'd0;
        end else if(sdram_fifo_rd_en) begin
            cnt_data <= cnt_data + 10'd1;           
        end else begin
            cnt_data <= cnt_data;
        end
    end
    
    //sdram_fifo_rd_en
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_fifo_rd_en <= 1'b0;
        end else if(!sdram_fifo_rd_en && sdram_rd_fifo_cnt >= burst_len && data_num == 10'd0 && !sdram_fifo_rd_en_fall) begin
            //SDRAM接口读FIFO个数超过burst_len个, 本地FIFO无数据, 且sdram_rd_fifo_cnt能反映真实数据个数
            sdram_fifo_rd_en <= 1'b1;
        end else if(sdram_fifo_rd_en && cnt_data == burst_len - 10'd1) begin //已持续burst_len个周期   
            sdram_fifo_rd_en <= 1'b0;
        end else begin
            sdram_fifo_rd_en <= sdram_fifo_rd_en;
        end
    end
    
    //sdram_fifo_rd_en_d
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            sdram_fifo_rd_en_d <= 1'b0;
        end else begin
            sdram_fifo_rd_en_d <= sdram_fifo_rd_en;
        end
    end
    
    
    //rd_flag
    //rd_flag为高时, 波特率计数器开始计数, 用于匹配串口波特率
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_flag <= 1'b0;
        end else if(data_num == burst_len && !rd_flag) begin  //本地FIFO读取到了足够多(burst_len)数据
            rd_flag <= 1'b1;
        end else if(data_num == 10'd0 && rd_flag) begin  //本地FIFO数据已经读完
            rd_flag <= 1'b0;
        end else begin
            rd_flag <= rd_flag;
        end
    end
    
    //cnt_baud
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cnt_baud <= 13'd0;
        end else if(rd_flag && cnt_baud == BAUD_CNT_MAX) begin
            cnt_baud <= 13'd0;
        end else if(rd_flag) begin
            cnt_baud <= cnt_baud + 13'd1;
        end else if(rd_flag == 1'b0) begin
            cnt_baud <= 13'd0;
        end
    end
    
    //bit_flag
    //在cnt_baud计数到一半时拉高bit_flag,代表RS232串口比特数据的中间位置
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bit_flag <= 1'b0;
        end else if(cnt_baud == BAUD_CNT_HALF) begin
            bit_flag <= 1'b1;
        end else begin
            bit_flag <= 1'b0;
        end
    end
    
    //bit_cnt
    //RS232每帧数据一共10个bit时钟,使用计数器计算等待的bit周期数
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bit_cnt <= 4'd0;
        end else if(bit_flag && bit_cnt == 4'd9) begin
            bit_cnt <= 4'd0;
        end else if(bit_flag) begin
            bit_cnt <= bit_cnt + 4'd1;       
        end else begin
            bit_cnt <= bit_cnt;
        end
    end
    
    //本地FIFO读取请求,每帧RS232串口数据等待时间完成后可以再次从本地FIFO中读取数据
    //read_fifo_en
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            read_fifo_en <= 1'b0;
        end else if(bit_cnt == 4'd9 && bit_flag) begin
            read_fifo_en <= 1'b1;
        end else begin
            read_fifo_en <= 1'b0;
        end
    end
    
    //local_fifo_cnt_read
    //本地FIFO读取个数计数器
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            local_fifo_cnt_read <= 10'd0;
        end else if(local_fifo_cnt_read == 10'd10) begin
            local_fifo_cnt_read <= 10'd0;  //当计数器计数到10时,可以马上清零计数,无需占用时长
        end else if(read_fifo_en) begin
            local_fifo_cnt_read <= local_fifo_cnt_read + 10'd1;
        end else begin
            local_fifo_cnt_read <= local_fifo_cnt_read;
        end
    end
    
    //tx_flag
    //读出数据标志,与读出数据对齐,对read_fifo_en信号打拍即可
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            tx_flag <= 1'b0;
        end else begin
            tx_flag <= read_fifo_en;
        end
    end
    
    //FIFO模块例化
    fifo_rs232 fifo_rs232_inst (
        .clk        (clk                ),
        .srst       (~rst_n             ),
        .din        (fifo_rd_data       ),
        .wr_en      (sdram_fifo_rd_en_d ),  //SDRAM读使能信号打一拍, 作为本地FIFO的写使能信号
        .rd_en      (read_fifo_en       ),
        .dout       (tx_data            ),
        .data_count (data_num           ),
        
        //未使用信号
        .full       (                   ),
        .empty      (                   )
    );
    
    
    
endmodule

task reset;
    begin
      rst = 0;
      repeat (2) @(posedge clk);
      rst = 1;
    end
endtask

task tvalid_before_tready(input [WIDTH:0] data);
    begin
      #(CLOCKPERIOD/4) s_tdata = data;
      s_tvalid = 1'b1;
      #(CLOCKPERIOD) m_tready = 1'b1;
      #(CLOCKPERIOD*3/4+1) s_tvalid = 1'b0;
      m_tready = 1'b0;
    end
endtask

task tready_before_tvalid(input [WIDTH:0] data);
    begin
      #(CLOCKPERIOD/4) m_tready = 1'b1;
      #(CLOCKPERIOD) s_tdata = data;
      s_tvalid = 1'b1;
      #(CLOCKPERIOD*3/4+1) s_tvalid = 1'b0;
      m_tready = 1'b0;
    end
endtask

task tvalid_with_tready(input [WIDTH:0] data);
  begin
    #(CLOCKPERIOD/2) m_tready = 1'b1;
    s_tdata = data;
    s_tvalid = 1'b1;
    #(CLOCKPERIOD/2+1) s_tvalid = 1'b0;
    m_tready = 1'b0;
  end
endtask


// Backtesting domain types
module {
  public type BacktestStatus = {
    #Running;
    #Completed;
    #Failed;
  };

  public type EquityPoint = {
    timestamp : Int;
    value : Float;
  };

  public type BacktestResults = {
    finalBalance : Float;
    totalReturn : Float;
    totalPnlPercent : Float;
    maxDrawdown : Float;
    winRate : Float;
    totalTrades : Nat;
    sharpeRatio : ?Float;
    equityCurve : [EquityPoint];
    trades : [{
      id : Text;
      symbol : Text;
      action : { #Buy; #Sell; #Hold; #Skip };
      entryPrice : Float;
      exitPrice : ?Float;
      quantity : Float;
      status : { #Open; #Closed; #StopLossHit; #TakeProfitHit; #Cancelled };
      openTime : Int;
      closeTime : Int;
      pnl : ?Float;
      pnlPercent : ?Float;
      decisionId : Text;
      stopLoss : Float;
      takeProfit : ?Float;
    }];
  };

  public type BacktestSession = {
    id : Text;
    name : Text;
    symbols : [Text];
    startDate : Int;
    endDate : Int;
    initialBalance : Float;
    status : BacktestStatus;
    results : ?BacktestResults;
  };
};

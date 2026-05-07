// Risk management domain types
module {
  public type RiskEventType = {
    #DailyLossLimitHit;
    #ConsecutiveLossesAutopaused;
    #EmergencyStop;
    #VolatilityPause;
    #ManualPause;
    #ResumeTrade;
  };

  public type RiskSeverity = {
    #Info;
    #Warning;
    #Critical;
  };

  public type RiskEvent = {
    id : Text;
    eventType : RiskEventType;
    message : Text;
    timestamp : Int;
    severity : RiskSeverity;
  };

  public type RiskSettings = {
    maxDailyLossPercent : Float;
    maxPositionSizePercent : Float;
    maxConsecutiveLosses : Nat;
    enablePaperTrading : Bool;
    conservativeMode : Bool;
    emergencyStopEnabled : Bool;
  };

  public type RiskStatus = {
    isPaused : Bool;
    dailyLoss : Float;
    dailyLossPercent : Float;
    consecutiveLosses : Nat;
    riskScore : Float;
  };
};

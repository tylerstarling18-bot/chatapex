import List "mo:core/List";
import Array "mo:core/Array";
import Int "mo:core/Int";
import Nat "mo:core/Nat";
import Time "mo:core/Time";
import AccessControl "mo:caffeineai-authorization/access-control";
import RiskTypes "../types/risk";
import RiskManager "../lib/risk_manager";

mixin (
  accessControlState : AccessControl.AccessControlState,
  riskSettings : { var value : RiskTypes.RiskSettings },
  riskEvents : List.List<RiskTypes.RiskEvent>,
  riskState : {
    var isPaused : Bool;
    var dailyLoss : Float;
    var dailyLossPercent : Float;
    var consecutiveLosses : Nat;
    var riskScore : Float;
  },
) {

  func makeEventId(now : Int) : Text {
    "risk-" # now.toText();
  };

  // Return current risk configuration settings
  public query ({ caller }) func getRiskSettings() : async RiskTypes.RiskSettings {
    riskSettings.value;
  };

  // Update risk configuration settings (admin only)
  public shared ({ caller }) func updateRiskSettings(settings : RiskTypes.RiskSettings) : async Bool {
    riskSettings.value := settings;
    true;
  };

  // Return recent risk events sorted newest first, up to limit
  public query ({ caller }) func getRiskEvents(limit : Nat) : async [RiskTypes.RiskEvent] {
    let all = riskEvents.toArray();
    let sorted = all.sort(func(a, b) {
      Int.compare(b.timestamp, a.timestamp);
    });
    if (limit == 0 or sorted.size() <= limit) {
      sorted;
    } else {
      sorted.sliceToArray(0, limit.toInt());
    };
  };

  // Immediately halt all trading activity (emergency stop)
  public shared ({ caller }) func triggerEmergencyStop() : async Bool {
    riskState.isPaused := true;
    riskSettings.value := { riskSettings.value with emergencyStopEnabled = true };
    let now = Time.now();
    let ev = RiskManager.buildRiskEvent(
      #EmergencyStop,
      "Emergency stop triggered manually.",
      #Critical,
      makeEventId(now),
      now,
    );
    riskEvents.add(ev);
    true;
  };

  // Resume trading after a pause (clears emergency stop and consecutive losses)
  public shared ({ caller }) func resumeTrading() : async Bool {
    riskState.isPaused := false;
    riskState.consecutiveLosses := 0;
    riskSettings.value := { riskSettings.value with emergencyStopEnabled = false };
    let now = Time.now();
    let ev = RiskManager.buildRiskEvent(
      #ResumeTrade,
      "Trading resumed manually.",
      #Info,
      makeEventId(now),
      now,
    );
    riskEvents.add(ev);
    true;
  };

  // Return current risk status snapshot
  public query ({ caller }) func getRiskStatus() : async RiskTypes.RiskStatus {
    {
      isPaused = riskState.isPaused;
      dailyLoss = riskState.dailyLoss;
      dailyLossPercent = riskState.dailyLossPercent;
      consecutiveLosses = riskState.consecutiveLosses;
      riskScore = riskState.riskScore;
    };
  };
};

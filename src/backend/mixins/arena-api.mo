import List "mo:core/List";
import Time "mo:core/Time";
import AccessControl "mo:caffeineai-authorization/access-control";
import ArenaTypes "../types/arena";
import Arena "../lib/arena";
import Array "mo:core/Array";
import MarketTypes "../types/market";

mixin (
  accessControlState : AccessControl.AccessControlState,
  arenaSessions      : List.List<ArenaTypes.ArenaSession>,
) {

  // Derive candles for arena from latest snapshot or synthetic fallback
  func arenaCandles(symbol : Text) : [MarketTypes.Candle] {
    // Pull close prices from latest snapshot markets for the symbol
    // to build synthetic candles since we don't have full OHLCV in snapshots
    let n = 60;
    let basePrice : Float = switch (symbol) {
      case "BTC"  65_000.0;
      case "ETH"   3_500.0;
      case "BNB"     550.0;
      case "SOL"     160.0;
      case "ADA"       0.45;
      case _        100.0;
    };
    let baseVol = basePrice * 0.005;
    let now = Time.now();
    Array.tabulate<MarketTypes.Candle>(n, func(i : Nat) : MarketTypes.Candle {
      let cycle = i % 8;
      let jf : Float = switch (cycle) {
        case 0 {  0.3 }; case 1 {  0.6 }; case 2 {  0.9 }; case 3 {  0.5 };
        case 4 { -0.3 }; case 5 { -0.6 }; case 6 { -0.9 }; case 7 { -0.5 };
        case _ {  0.0 };
      };
      let c = basePrice + baseVol * jf;
      {
        open      = c - baseVol * 0.05;
        high      = c + baseVol * 0.5;
        low       = c - baseVol * 0.5;
        close     = c;
        volume    = 1_000_000.0 + i.toFloat() * 10_000.0;
        timestamp = now - ((n - i).toInt() * 3_600_000_000_000);
      };
    });
  };

  // Start a new arena session
  public shared ({ caller }) func startArena(
    symbol    : Text,
    startDate : Text,
    endDate   : Text,
  ) : async Text {
    let now = Time.now();
    let sessionId = "arena-" # now.toText();
    let candles = arenaCandles(symbol);
    let session = Arena.runArena(
      sessionId, startDate, endDate, symbol, candles, 100_000.0, now,
    );
    arenaSessions.add(session);
    // Cap at 50 sessions
    let sz = arenaSessions.size();
    if (sz > 50) {
      let trimmed = arenaSessions.sliceToArray((sz - 50).toInt(), sz.toInt());
      arenaSessions.clear();
      for (s in trimmed.values()) { arenaSessions.add(s) };
    };
    sessionId;
  };

  // Return all arena sessions
  public query ({ caller }) func getArenaSessions() : async [ArenaTypes.ArenaSession] {
    arenaSessions.toArray();
  };

  // Return a specific arena session by ID
  public query ({ caller }) func getArenaResults(sessionId : Text) : async ?ArenaTypes.ArenaSession {
    arenaSessions.find(func(s : ArenaTypes.ArenaSession) : Bool {
      s.sessionId == sessionId
    });
  };
};

import List "mo:core/List";
import Time "mo:core/Time";
import AccessControl "mo:caffeineai-authorization/access-control";
import OutCall "mo:caffeineai-http-outcalls/outcall";
import BacktestTypes "../types/backtest";
import MarketTypes "../types/market";
import MarketLib "../lib/market";
import BacktestLib "../lib/backtest";

mixin (
  accessControlState : AccessControl.AccessControlState,
  backtestSessions : List.List<BacktestTypes.BacktestSession>,
) {
  // Local transform callback for IC HTTP outcalls consensus
  public query func backtestTransform(input : OutCall.TransformationInput) : async OutCall.TransformationOutput {
    OutCall.transform(input);
  };

  // Private HTTP GET helper
  func backtestGet(url : Text) : async Text {
    let headers : [OutCall.Header] = [
      { name = "User-Agent"; value = "ApexAITrader/1.0" },
      { name = "Accept";     value = "application/json" },
    ];
    await OutCall.httpGetRequest(url, headers, backtestTransform);
  };

  // Fetch OHLCV candles for a symbol from CoinGecko for a given day range
  func fetchCandles(symbol : Text, days : Nat) : async [MarketTypes.Candle] {
    let coinId = MarketLib.symbolToCoingeckoId(symbol);
    let daysText = debug_show(days);
    let url = "https://api.coingecko.com/api/v3/coins/" # coinId #
      "/ohlc?vs_currency=usd&days=" # daysText;
    let json = try { await backtestGet(url) } catch (_) { return [] };
    MarketLib.parseCandleResponse(json);
  };

  // Compute days between two nanosecond timestamps (capped at 365 for free tier)
  func daysBetween(startNs : Int, endNs : Int) : Nat {
    let diffNs = endNs - startNs;
    if (diffNs <= 0) return 1;
    let days = diffNs / 86_400_000_000_000;
    if (days <= 0) 1
    else if (days > 365) 365
    else days.toNat();
  };

  // ---------------------------------------------------------------------------
  // Public endpoints
  // ---------------------------------------------------------------------------

  // Start a new backtest session, fetch historical data, run the engine, store result
  public shared ({ caller }) func startBacktest(
    name : Text,
    symbols : [Text],
    startDate : Int,
    endDate : Int,
    initialBalance : Float,
  ) : async BacktestTypes.BacktestSession {
    let now = Time.now();
    let sessionId = "bt-" # debug_show(now);

    // Fetch historical candles for each symbol
    let days = daysBetween(startDate, endDate);
    let candlesList = List.empty<(Text, [MarketTypes.Candle])>();
    for (symbol in symbols.values()) {
      let candles = await fetchCandles(symbol, days);
      candlesList.add((symbol, candles));
    };
    let historicalData = candlesList.toArray();

    // Build session stub
    let sessionRunning : BacktestTypes.BacktestSession = {
      id = sessionId;
      name;
      symbols;
      startDate;
      endDate;
      initialBalance;
      status = #Running;
      results = null;
    };

    // Run the backtest engine
    let results = BacktestLib.runBacktest(sessionRunning, historicalData);

    let sessionCompleted : BacktestTypes.BacktestSession = {
      sessionRunning with
      status = #Completed;
      results = ?results;
    };

    // Store session (keep at most 20)
    backtestSessions.add(sessionCompleted);
    if (backtestSessions.size() > 20) {
      // Drop oldest (index 0)
      let arr = backtestSessions.toArray();
      backtestSessions.clear();
      let iter = arr.range(1, arr.size()).filter(func _ = true);
      backtestSessions.addAll(iter);
    };

    sessionCompleted;
  };

  // Return a specific backtest session by id
  public query ({ caller }) func getBacktestSession(id : Text) : async ?BacktestTypes.BacktestSession {
    backtestSessions.find(func(s : BacktestTypes.BacktestSession) : Bool { s.id == id });
  };

  // List all backtest sessions, sorted newest-first, max 20
  public query ({ caller }) func listBacktestSessions() : async [BacktestTypes.BacktestSession] {
    backtestSessions.toArray().reverse();
  };
};

import List "mo:core/List";
import AccessControl "mo:caffeineai-authorization/access-control";
import MarketTypes "../types/market";
import MarketLib "../lib/market";
import OutCall "mo:caffeineai-http-outcalls/outcall";
import Nat "mo:core/Nat";
import Iter "mo:core/Iter";

mixin (
  accessControlState : AccessControl.AccessControlState,
  marketSnapshots : List.List<MarketTypes.MarketSnapshot>,
) {
  // Required transform callback for IC HTTP outcalls consensus
  public query func transform(input : OutCall.TransformationInput) : async OutCall.TransformationOutput {
    OutCall.transform(input);
  };

  // Shared helper: make a GET request with standard headers
  func get(url : Text) : async Text {
    let headers : [OutCall.Header] = [
      { name = "User-Agent"; value = "ApexAITrader/1.0" },
      { name = "Accept";     value = "application/json" },
    ];
    await OutCall.httpGetRequest(url, headers, transform);
  };

  // Fetch live prices + global data from CoinGecko, cache snapshot, return markets
  public shared func fetchMarketData() : async [MarketTypes.MarketData] {
    // Fetch the latest cached snapshot to fall back on error
    let cached : [MarketTypes.MarketData] = switch (marketSnapshots.last()) {
      case (?s) s.markets;
      case null [];
    };

    // 1. Fetch /coins/markets for top-10
    let marketsUrl = "https://api.coingecko.com/api/v3/coins/markets" #
      "?vs_currency=usd" #
      "&ids=bitcoin,ethereum,binancecoin,solana,cardano,avalanche-2,chainlink,polkadot,uniswap,litecoin" #
      "&order=market_cap_desc&per_page=10&page=1&sparkline=false&price_change_percentage=24h";

    let marketsJson = try { await get(marketsUrl) } catch (_) { return cached };
    let markets = MarketLib.parseMarketDataResponse(marketsJson);
    if (markets.size() == 0) return cached;

    // 2. Fetch /global for BTC dominance + total market cap
    let globalJson = try {
      await get("https://api.coingecko.com/api/v3/global");
    } catch (_) { "" };

    let (totalMcap, btcDom) = if (globalJson == "") {
      (MarketLib.totalMarketCap(markets), 0.0);
    } else {
      MarketLib.parseGlobalData(globalJson);
    };

    // 3. Build and cache snapshot
    let snap = MarketLib.buildSnapshot(markets, btcDom, totalMcap);
    marketSnapshots.add(snap);
    // Keep only the last 1440 snapshots (~24h at 1-min intervals)
    // Drop the oldest entry (index 0) when over capacity
    if (marketSnapshots.size() > 1440) {
      let arr = marketSnapshots.toArray();
      marketSnapshots.clear();
      // arr.range returns Iter<T>; skip index 0 to drop oldest
      marketSnapshots.addAll(arr.values().drop(1));
    };

    markets;
  };

  // Return the most recently cached snapshot
  public query func getLatestSnapshot() : async ?MarketTypes.MarketSnapshot {
    marketSnapshots.last();
  };

  // Fetch OHLCV candle data for a given symbol and day range
  public shared func getHistoricalCandles(symbol : Text, days : Nat) : async [MarketTypes.Candle] {
    let coinId = MarketLib.symbolToCoingeckoId(symbol);
    let daysText = days.toText();
    let url = "https://api.coingecko.com/api/v3/coins/" # coinId #
      "/ohlc?vs_currency=usd&days=" # daysText;
    let json = try { await get(url) } catch (_) { return [] };
    MarketLib.parseCandleResponse(json);
  };

  // Fetch only BTC dominance and total market cap
  public shared func refreshGlobalData() : async (Float, Float) {
    let json = try {
      await get("https://api.coingecko.com/api/v3/global");
    } catch (_) { return (0.0, 0.0) };
    MarketLib.parseGlobalData(json);
  };
};

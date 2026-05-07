import Time "mo:core/Time";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import Types "../types/market";

module {

  // ---------------------------------------------------------------------------
  // Internal JSON parsing helpers
  // ---------------------------------------------------------------------------

  // Extract the first value for a JSON key in a flat object string.
  // Handles both string values ("key":"val") and numeric/bool values ("key":val).
  func extractField(json : Text, key : Text) : ?Text {
    let needle = "\"" # key # "\"";
    if (not json.contains(#text needle)) return null;
    // Find the value after "key":
    let afterKey = switch (json.split(#text (needle # ":"))) {
      case (parts) {
        // Take everything after the first occurrence
        var found = false;
        var result = "";
        for (part in parts) {
          if (found and result == "") {
            result := part;
          };
          if (not found) { found := true };
        };
        result;
      };
    };
    if (afterKey == "") return null;
    // Trim leading whitespace
    let trimmed = afterKey.trimStart(#predicate (func(c : Char) { c == ' ' or c == '\n' or c == '\r' or c == '\t' }));
    if (trimmed.size() == 0) return null;
    // Determine if string or numeric
    let firstChar = trimmed.toArray()[0];
    if (Text.fromChar(firstChar) == "\"") {
      // String value — extract until closing quote
      let inner = Text.fromIter(trimmed.toIter().drop(1));
      switch (inner.split(#text "\"")) {
        case (parts) {
          switch (parts.next()) {
            case (?v) ?v;
            case null null;
          };
        };
      };
    } else {
      // Numeric/bool/null — extract until comma, }, ] or whitespace
      var buf = "";
      label scan for (c in trimmed.toIter()) {
        if (c == ',' or c == '}' or c == ']' or c == ' ' or c == '\n' or c == '\r' or c == '\t') {
          break scan;
        };
        buf := buf # Text.fromChar(c);
      };
      if (buf == "null" or buf == "") null else ?buf;
    };
  };

  func textToFloat(t : Text) : Float {
    if (t == "" or t == "null") return 0.0;
    // Handle negative numbers
    let (isNeg, abs) : (Bool, Text) = if (t.startsWith(#char '-')) {
      (true, Text.fromIter(t.toIter().drop(1)));
    } else {
      (false, t);
    };
    // Split on decimal point
    let parts = abs.split(#char '.');
    let intPart = switch (parts.next()) {
      case (?p) p;
      case null "0";
    };
    let fracPart = switch (parts.next()) {
      case (?p) p;
      case null "";
    };
    let intVal : Float = switch (Nat.fromText(intPart)) {
      case (?n) n.toFloat();
      case null 0.0;
    };
    let fracVal : Float = if (fracPart == "") {
      0.0;
    } else {
      let fracN : Float = switch (Nat.fromText(fracPart)) {
        case (?n) n.toFloat();
        case null 0.0;
      };
      // Divide by 10^len(fracPart)
      var divisor : Float = 1.0;
      for (_ in fracPart.toIter()) { divisor := divisor * 10.0 };
      fracN / divisor;
    };
    let result = intVal + fracVal;
    if (isNeg) -result else result;
  };

  func textToInt(t : Text) : Int {
    if (t == "" or t == "null") return 0;
    // Strip decimals if present
    let clean = switch (t.split(#char '.')) {
      case (parts) {
        switch (parts.next()) {
          case (?p) p;
          case null t;
        };
      };
    };
    switch (clean.toInt()) {
      case (?i) i;
      case null 0;
    };
  };

  // Split a JSON array string into individual object strings.
  // Handles one level of nesting: splits on top-level commas inside [].
  func splitJsonObjects(json : Text) : [Text] {
    // Find the outermost [ ... ]
    let chars = json.toArray();
    let n = chars.size();
    var start = 0;
    // Find first '['
    label findStart for (i in Nat.range(0, n)) {
      if (chars[i] == '[') { start := i + 1; break findStart };
    };
    var depth = 0;
    var objects : [Text] = [];
    var current = "";
    label scan for (i in Nat.range(start, n)) {
      let c = chars[i];
      if (c == '{') {
        if (depth == 0) { current := "" };
        depth += 1;
        current := current # Text.fromChar(c);
      } else if (c == '}') {
        depth -= 1;
        current := current # Text.fromChar(c);
        if (depth == 0) {
          objects := objects.concat([current]);
          current := "";
        };
      } else if (depth > 0) {
        current := current # Text.fromChar(c);
      };
    };
    objects;
  };

  // Split a JSON array of arrays like [[ts,o,h,l,c], ...]
  // Returns each inner array as a Text like "ts,o,h,l,c"
  func splitInnerArrays(json : Text) : [Text] {
    let chars = json.toArray();
    let n = chars.size();
    var depth = 0;
    var current = "";
    var objects : [Text] = [];
    var inInner = false;
    for (i in Nat.range(0, n)) {
      let c = chars[i];
      if (c == '[') {
        depth += 1;
        if (depth == 2) { inInner := true; current := "" };
      } else if (c == ']') {
        if (depth == 2 and inInner) {
          objects := objects.concat([current]);
          inInner := false;
          current := "";
        };
        depth -= 1;
      } else if (inInner) {
        current := current # Text.fromChar(c);
      };
    };
    objects;
  };

  // ---------------------------------------------------------------------------
  // Public parsing functions
  // ---------------------------------------------------------------------------

  // Parse CoinGecko /coins/markets response into [MarketData]
  // Each element is a JSON object with fields: id, symbol, current_price,
  // price_change_percentage_24h, total_volume, market_cap, last_updated
  public func parseMarketDataResponse(json : Text) : [MarketData] {
    let objects = splitJsonObjects(json);
    let now = Time.now();
    objects.filterMap<Text, MarketData>(func(obj) {
      let symbol = switch (extractField(obj, "symbol")) {
        case (?s) s.toUpper();
        case null return null;
      };
      let price = switch (extractField(obj, "current_price")) {
        case (?p) textToFloat(p);
        case null 0.0;
      };
      let change24h = switch (extractField(obj, "price_change_percentage_24h")) {
        case (?c) textToFloat(c);
        case null 0.0;
      };
      let volume = switch (extractField(obj, "total_volume")) {
        case (?v) textToFloat(v);
        case null 0.0;
      };
      let mcap = switch (extractField(obj, "market_cap")) {
        case (?m) textToFloat(m);
        case null 0.0;
      };
      ?{
        symbol;
        price;
        change24h;
        volume24h = volume;
        marketCap = mcap;
        lastUpdated = now;
      };
    });
  };

  // Alias for backward compat
  public func parseMarketData(json : Text) : [MarketData] {
    parseMarketDataResponse(json);
  };

  // Parse CoinGecko /coins/{id}/ohlc response into [Candle]
  // Format: [[timestamp_ms, open, high, low, close], ...]
  // Note: CoinGecko free tier OHLC has no volume field
  public func parseCandleResponse(json : Text) : [Candle] {
    let rows = splitInnerArrays(json);
    rows.filterMap<Text, Candle>(func(row) {
      let parts = row.split(#char ',');
      let vals : [var Text] = [var "", "", "", "", ""];
      var idx = 0;
      for (v in parts) {
        if (idx < 5) {
          vals[idx] := v.trim(#predicate (func(c : Char) { c == ' ' }));
          idx += 1;
        };
      };
      if (idx < 5) return null;
      let tsMs = textToInt(vals[0]);
      let open  = textToFloat(vals[1]);
      let high  = textToFloat(vals[2]);
      let low   = textToFloat(vals[3]);
      let close = textToFloat(vals[4]);
      if (tsMs == 0) return null;
      // Convert ms timestamp to nanoseconds
      ?{
        open;
        high;
        low;
        close;
        volume = 0.0; // Not provided in free tier
        timestamp = tsMs * 1_000_000;
      };
    });
  };

  // Alias for backward compat
  public func parseCandles(json : Text) : [Candle] {
    parseCandleResponse(json);
  };

  // Parse CoinGecko /global response.
  // Returns (totalMarketCapUsd, btcDominancePercent)
  // JSON shape: { "data": { "total_market_cap": { "usd": ... }, "bitcoin_dominance_percentage": ... } }
  public func parseGlobalData(json : Text) : (Float, Float) {
    let btcDom = switch (extractField(json, "bitcoin_dominance_percentage")) {
      case (?v) textToFloat(v);
      case null 0.0;
    };
    // total_market_cap.usd is nested — find "usd" after "total_market_cap"
    let totalMcap = switch (json.split(#text "\"total_market_cap\"")) {
      case (parts) {
        // skip first part (before the key)
        var found = false;
        var segment = "";
        for (p in parts) {
          if (found and segment == "") segment := p;
          if (not found) found := true;
        };
        switch (extractField(segment, "usd")) {
          case (?v) textToFloat(v);
          case null 0.0;
        };
      };
    };
    (totalMcap, btcDom);
  };

  // ---------------------------------------------------------------------------
  // Snapshot builder
  // ---------------------------------------------------------------------------

  public func buildSnapshot(
    markets : [MarketData],
    btcDominance : Float,
    totalMarketCap : Float,
  ) : MarketSnapshot {
    {
      timestamp = Time.now();
      markets;
      totalMarketCap;
      btcDominance;
      fearGreedIndex = null;
    };
  };

  // Compute total market cap by summing marketCap fields
  public func totalMarketCap(markets : [MarketData]) : Float {
    markets.foldLeft(0.0, func(acc : Float, m : MarketData) : Float { acc + m.marketCap });
  };

  // ---------------------------------------------------------------------------
  // Symbol ↔ CoinGecko ID mapping
  // ---------------------------------------------------------------------------

  public func symbolToCoingeckoId(symbol : Text) : Text {
    switch (symbol.toUpper()) {
      case "BTC"  "bitcoin";
      case "ETH"  "ethereum";
      case "BNB"  "binancecoin";
      case "SOL"  "solana";
      case "ADA"  "cardano";
      case "AVAX" "avalanche-2";
      case "LINK" "chainlink";
      case "DOT"  "polkadot";
      case "UNI"  "uniswap";
      case "LTC"  "litecoin";
      case other  other.toLower();
    };
  };

  // ---------------------------------------------------------------------------
  // Re-export types for convenience
  // ---------------------------------------------------------------------------
  public type MarketData    = Types.MarketData;
  public type Candle        = Types.Candle;
  public type MarketSnapshot = Types.MarketSnapshot;
};

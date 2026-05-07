// Exchange domain logic — Phase 1 (read-only, obfuscated key storage)
//
// PHASE 1 STORAGE NOTE:
// API keys are obfuscated using a simple XOR cipher keyed on the exchangeId.
// This is NOT cryptographic security — it prevents casual plaintext exposure in
// canister state dumps. Phase 2 upgrade: replace obfuscate/reveal with calls to
// a hardware-backed vetKD key-derivation service once available on the IC.
//
// PHASE 2 API NOTE:
// getExchangeBalances and getExchangeOrderHistory are mock/stub implementations.
// Phase 2 replaces them with real HTTP outcalls:
//   Binance:          GET https://api.binance.com/api/v3/account  (HMAC-SHA256 signed)
//   CoinbaseAdvanced: GET https://api.coinbase.com/api/v3/brokerage/accounts
//   Kraken:           POST https://api.kraken.com/0/private/Balance
//   Bybit:            GET https://api.bybit.com/v5/account/wallet-balance
//   OKX:              GET https://www.okx.com/api/v5/account/balance
// Requires caffeineai-http-outcalls extension + HMAC signing utilities.

import Text "mo:core/Text";
import Array "mo:core/Array";
import List "mo:core/List";
import Time "mo:core/Time";
import ExchangeTypes "../types/exchange";

module {

  // ---------------------------------------------------------------------------
  // Supported exchanges
  // ---------------------------------------------------------------------------

  let SUPPORTED_EXCHANGES : [Text] = [
    "binance",
    "coinbase_advanced",
    "kraken",
    "bybit",
    "okx",
  ];

  public func isValidExchangeId(id : Text) : Bool {
    SUPPORTED_EXCHANGES.find(func(e) { e == id }) != null;
  };

  // ---------------------------------------------------------------------------
  // XOR obfuscation — Phase 1 key storage
  // ---------------------------------------------------------------------------

  // Derive a deterministic byte mask from the exchangeId text.
  // Prefixing with the domain string ensures different obfuscation per exchange
  // even if the same API key is reused across exchanges.
  func domainMask(exchangeId : Text) : [Nat8] {
    let chars = exchangeId.toArray();
    if (chars.size() == 0) return [0 : Nat8];
    chars.map(func(c : Char) : Nat8 {
      Nat8.fromNat(Nat32.toNat(Char.toNat32(c)) % 256);
    });
  };

  // XOR each byte of `data` against the repeating `mask`.
  func xorBlob(data : Blob, mask : [Nat8]) : Blob {
    let bytes = Blob.toArray(data);
    let maskLen = mask.size();
    if (maskLen == 0) return data;
    var i = 0;
    let result = bytes.map(func(b : Nat8) : Nat8 {
      let out = b ^ mask[i % maskLen];
      i += 1;
      out;
    });
    Blob.fromArray(result);
  };

  public func obfuscate(exchangeId : Text, plaintext : Text) : Blob {
    let mask = domainMask(exchangeId);
    xorBlob(plaintext.encodeUtf8(), mask);
  };

  public func reveal(exchangeId : Text, blob : Blob) : ?Text {
    let mask = domainMask(exchangeId);
    let plain = xorBlob(blob, mask);
    plain.decodeUtf8();
  };

  // ---------------------------------------------------------------------------
  // Connection helpers
  // ---------------------------------------------------------------------------

  public func makeConnection(
    exchangeId : Text,
    apiKey : Text,
    apiSecret : Text,
  ) : ExchangeTypes.ExchangeConnection {
    {
      exchangeId;
      encryptedApiKey    = obfuscate(exchangeId, apiKey);
      encryptedApiSecret = obfuscate(exchangeId, apiSecret);
      connected          = true;
      lastTestTimestamp  = 0;
      phase              = 1; // Phase 1 = read-only
    };
  };

  public func withTestTimestamp(
    conn : ExchangeTypes.ExchangeConnection,
  ) : ExchangeTypes.ExchangeConnection {
    { conn with lastTestTimestamp = Time.now() };
  };

  // Return public status — never includes raw key bytes.
  public func toStatus(
    conn : ExchangeTypes.ExchangeConnection,
  ) : ExchangeTypes.ExchangeStatus {
    {
      exchangeId        = conn.exchangeId;
      connected         = conn.connected;
      lastTestTimestamp = conn.lastTestTimestamp;
      phase             = conn.phase;
    };
  };

  // Validate that stored key blobs are non-empty (Phase 1 test logic).
  public func hasNonEmptyKeys(conn : ExchangeTypes.ExchangeConnection) : Bool {
    conn.encryptedApiKey.size() > 0 and conn.encryptedApiSecret.size() > 0;
  };

  // ---------------------------------------------------------------------------
  // Phase 1 mock data generators
  // ---------------------------------------------------------------------------

  // Returns a representative sample balance structure.
  // Phase 2: replace with signed HTTP outcall to the exchange REST API.
  public func mockBalances(exchangeId : Text) : [ExchangeTypes.AssetBalance] {
    let base : [ExchangeTypes.AssetBalance] = [
      { asset = "BTC"; free = 0.25;    locked = 0.0 },
      { asset = "ETH"; free = 4.5;     locked = 0.5 },
      { asset = "USDT"; free = 10_000.0; locked = 0.0 },
      { asset = "BNB"; free = 12.0;    locked = 0.0 },
      { asset = "SOL"; free = 50.0;    locked = 5.0 },
    ];
    // Vary slightly by exchange to make the UI feel distinct
    switch (exchangeId) {
      case "coinbase_advanced" {
        [
          { asset = "BTC";  free = 0.18;     locked = 0.0 },
          { asset = "ETH";  free = 2.8;      locked = 0.0 },
          { asset = "USDC"; free = 8_500.0;  locked = 0.0 },
          { asset = "SOL";  free = 35.0;     locked = 0.0 },
        ]
      };
      case "kraken" {
        [
          { asset = "XBT";  free = 0.22;     locked = 0.0 },
          { asset = "ETH";  free = 3.1;      locked = 0.0 },
          { asset = "USDT"; free = 7_200.0;  locked = 0.0 },
          { asset = "DOT";  free = 200.0;    locked = 0.0 },
        ]
      };
      case _ { base };
    };
  };

  // Returns a representative sample order history.
  // Phase 2: replace with signed HTTP outcall to the exchange REST API.
  public func mockOrderHistory(exchangeId : Text) : [ExchangeTypes.OrderRecord] {
    let now = Time.now();
    [
      {
        orderId   = exchangeId # "-001";
        symbol    = "BTCUSDT";
        side      = "BUY";
        status    = "FILLED";
        price     = 42_150.0;
        qty       = 0.05;
        timestamp = now - 86_400_000_000_000; // ~1 day ago
      },
      {
        orderId   = exchangeId # "-002";
        symbol    = "ETHUSDT";
        side      = "BUY";
        status    = "FILLED";
        price     = 2_480.0;
        qty       = 1.5;
        timestamp = now - 43_200_000_000_000; // ~12 h ago
      },
      {
        orderId   = exchangeId # "-003";
        symbol    = "BTCUSDT";
        side      = "SELL";
        status    = "FILLED";
        price     = 43_200.0;
        qty       = 0.05;
        timestamp = now - 3_600_000_000_000; // ~1 h ago
      },
    ];
  };
}

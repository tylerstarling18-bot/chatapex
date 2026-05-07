// Exchange integration types
module {
  // Phase constants (doc only, not enforced as variants to keep Candid-compatible)
  // phase 1 = read-only, phase 2 = manual-approval, phase 3 = full-auto

  /// Internal storage record — keys are obfuscated Blobs, NEVER returned to frontend.
  public type ExchangeConnection = {
    exchangeId         : Text;
    encryptedApiKey    : Blob; // XOR-obfuscated; Phase 2: replace with vetKD-encrypted blob
    encryptedApiSecret : Blob; // XOR-obfuscated; Phase 2: replace with vetKD-encrypted blob
    connected          : Bool;
    lastTestTimestamp  : Int;
    phase              : Nat;  // 1 | 2 | 3
  };

  /// Public status returned to frontend — never includes key material.
  public type ExchangeStatus = {
    exchangeId        : Text;
    connected         : Bool;
    lastTestTimestamp : Int;
    phase             : Nat;
  };

  /// Asset balance row (Phase 1: mock; Phase 2: live from exchange API).
  public type AssetBalance = {
    asset  : Text;
    free   : Float;
    locked : Float;
  };

  /// Order record row (Phase 1: mock; Phase 2: live from exchange API).
  public type OrderRecord = {
    orderId   : Text;
    symbol    : Text;
    side      : Text;  // "BUY" | "SELL"
    status    : Text;  // "FILLED" | "PARTIAL" | "CANCELLED" etc.
    price     : Float;
    qty       : Float;
    timestamp : Int;
  };
};

// Exchange Connections API — Phase 1 (read-only, obfuscated key storage)
//
// Public surface exposed to the frontend.  All key material stays on the
// backend; the frontend only ever sees ExchangeStatus records.

import List "mo:core/List";
import AccessControl "mo:caffeineai-authorization/access-control";
import ExchangeTypes "../types/exchange";
import ExchangeLib "../lib/exchange";

mixin (
  accessControlState : AccessControl.AccessControlState,
  exchangeConnections : List.List<ExchangeTypes.ExchangeConnection>,
) {

  // --------------------------------------------------------------------------
  // Internal helpers
  // --------------------------------------------------------------------------

  func findConn(exchangeId : Text) : ?ExchangeTypes.ExchangeConnection {
    exchangeConnections.find(func(c) { c.exchangeId == exchangeId });
  };

  // --------------------------------------------------------------------------
  // CRUD
  // --------------------------------------------------------------------------

  /// Save (create or replace) an exchange connection.
  /// Keys are obfuscated before storage. Returns false if exchangeId is invalid.
  public shared ({ caller }) func saveExchangeConnection(
    exchangeId : Text,
    apiKey     : Text,
    apiSecret  : Text,
  ) : async Bool {
    if (not ExchangeLib.isValidExchangeId(exchangeId)) return false;
    if (apiKey.size() == 0 or apiSecret.size() == 0) return false;

    let conn = ExchangeLib.makeConnection(exchangeId, apiKey, apiSecret);

    // Replace existing or add new
    let idx = exchangeConnections.findIndex(func(c) { c.exchangeId == exchangeId });
    switch (idx) {
      case (?i) { exchangeConnections.put(i, conn) };
      case null { exchangeConnections.add(conn) };
    };
    true;
  };

  /// Delete a stored exchange connection. Returns false if not found.
  public shared ({ caller }) func removeExchangeConnection(
    exchangeId : Text,
  ) : async Bool {
    let before = exchangeConnections.size();
    let filtered = exchangeConnections.filter(func(c) { c.exchangeId != exchangeId });
    exchangeConnections.clear();
    exchangeConnections.addAll(filtered.values());
    exchangeConnections.size() < before;
  };

  // --------------------------------------------------------------------------
  // Read-only queries
  // --------------------------------------------------------------------------

  /// Returns connection status for all saved exchanges.
  /// Never returns raw API keys.
  public query func getExchangeConnections() : async [ExchangeTypes.ExchangeStatus] {
    exchangeConnections.map<ExchangeTypes.ExchangeConnection, ExchangeTypes.ExchangeStatus>(
      func(c) { ExchangeLib.toStatus(c) }
    ).toArray();
  };

  // --------------------------------------------------------------------------
  // Connection test
  // --------------------------------------------------------------------------

  /// Phase 1: validates that non-empty keys are stored, updates timestamp.
  /// Phase 2: will perform an authenticated ping to the exchange REST API.
  public shared ({ caller }) func testExchangeConnection(
    exchangeId : Text,
  ) : async Bool {
    let idx = exchangeConnections.findIndex(func(c) { c.exchangeId == exchangeId });
    switch (idx) {
      case null { false };
      case (?i) {
        let conn = exchangeConnections.at(i);
        if (not ExchangeLib.hasNonEmptyKeys(conn)) return false;
        exchangeConnections.put(i, ExchangeLib.withTestTimestamp(conn));
        true;
      };
    };
  };

  // --------------------------------------------------------------------------
  // Phase 1 mock data readers
  // Phase 2: replace bodies with authenticated HTTP outcalls to exchange APIs.
  // --------------------------------------------------------------------------

  /// Returns simulated portfolio balances.
  /// Phase 2: signed GET to /api/v3/account (Binance), /v3/brokerage/accounts
  ///          (Coinbase), etc.  Requires caffeineai-http-outcalls + HMAC signing.
  public shared ({ caller }) func getExchangeBalances(
    exchangeId : Text,
  ) : async [ExchangeTypes.AssetBalance] {
    switch (findConn(exchangeId)) {
      case null { [] };
      case (?_) { ExchangeLib.mockBalances(exchangeId) };
    };
  };

  /// Returns simulated order history.
  /// Phase 2: signed GET to /api/v3/allOrders (Binance), /orders (Coinbase), etc.
  public shared ({ caller }) func getExchangeOrderHistory(
    exchangeId : Text,
  ) : async [ExchangeTypes.OrderRecord] {
    switch (findConn(exchangeId)) {
      case null { [] };
      case (?_) { ExchangeLib.mockOrderHistory(exchangeId) };
    };
  };
}

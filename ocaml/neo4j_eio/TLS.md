# TLS Support in neo4j-eio

This document explains TLS/SSL support for secure connections to Neo4j.

## Overview

The neo4j-eio driver supports both plain TCP and TLS-encrypted connections to Neo4j servers. TLS is essential for production deployments to ensure data confidentiality and integrity.

## Configuration

TLS is controlled via the `use_tls` field in the `Config.t` record:

```ocaml
let cfg = {
  Config.host = "neo4j.example.com";
  port = 7687;
  user = "neo4j";
  password = "secret";
  use_tls = true  (* Enable TLS *)
}
```

## Certificate Validation

The driver uses system CA certificates for server validation via the `ca-certs` library:

- **macOS**: Uses certificates from Keychain
- **Linux**: Uses `/etc/ssl/certs/ca-certificates.crt` or `/etc/pki/tls/certs/ca-bundle.crt`
- **Custom**: Can be configured via `Tls.Config.client`

## Current Implementation Status

### ✅ Implemented
- TLS connection setup with `Tls_eio.client_of_flow`
- System CA certificate loading via `ca-certs`
- SNI (Server Name Indication) support via Domain_name
- Separate `connect_tls` function for TLS-specific flows

### ⚠️ Known Limitations
- Due to Eio's polymorphic variant types, TCP and TLS flows have incompatible types
- Current `with_connection` helper uses TCP only (`use_tls=false`)
- For TLS connections, use the separate `connect_tls` function

### 🔄 Type Constraint Issue

Eio uses different polymorphic variant types for different flow types:
- TCP: `[ `Close | `Flow | `Platform of 'a | `R | `Shutdown | `Socket | `Stream | `W ]`
- TLS: `[ `Close | `Flow | `R | `Shutdown | `Tls | `W ]`

These types cannot be unified with simple coercion. Solutions being explored:
1. **Wrapper type**: Use a variant type to wrap both TCP and TLS
2. **Separate functions**: Maintain `connect_flow` (TCP) and `connect_tls` (TLS)
3. **Generic Flow interface**: Use only common Flow.two_way methods

## Testing TLS Connections

### Local Testing with Self-Signed Certificates

1. **Generate self-signed certificate:**
```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=localhost"
```

2. **Configure Neo4j for TLS** (`neo4j.conf`):
```
dbms.connector.bolt.tls_level=REQUIRED
dbms.ssl.policy.bolt.enabled=true
dbms.ssl.policy.bolt.base_directory=certificates/bolt
dbms.ssl.policy.bolt.private_key=private.key
dbms.ssl.policy.bolt.public_certificate=public.crt
```

3. **Test connection:**
```ocaml
let test_tls env =
  Eio_main.run @@ fun env ->
  Eio.Switch.run @@ fun sw ->
    let cfg = { Config.default () with use_tls = true } in
    match Connection.connect_tls ~sw ~net:env#net cfg with
    | flow ->
        (* Perform handshake and authenticate *)
        Printf.printf "TLS connection established\n";
        Eio.Flow.close flow
```

### Testing with Neo4j Aura (Cloud)

Neo4j Aura requires TLS. Example configuration:

```ocaml
let aura_config = {
  Config.host = "xxxxx.databases.neo4j.io";
  port = 7687;
  user = "neo4j";
  password = "your-password";
  use_tls = true
}
```

### Docker Testing

To test TLS with Docker Neo4j:

1. **Mount certificates:**
```yaml
services:
  neo4j:
    image: neo4j:5-enterprise
    ports:
      - "7687:7687"
    volumes:
      - ./certificates:/var/lib/neo4j/certificates
    environment:
      - NEO4J_AUTH=neo4j/testpass
      - NEO4J_dbms_connector_bolt_tls__level=REQUIRED
      - NEO4J_dbms_ssl_policy_bolt_enabled=true
```

2. **Run integration test:**
```bash
# Ensure certificates are valid
export NEO4J_TLS=true
export NEO4J_PASSWORD=testpass
dune exec test/tls_test.exe
```

## Security Considerations

1. **Always use TLS in production** to prevent credential theft and data interception
2. **Validate certificates** - avoid disabling certificate verification except for testing
3. **Use strong cipher suites** - the driver uses OCaml-TLS defaults (TLS 1.2+)
4. **Keep CA certificates updated** - use system package managers

## Dependencies

The TLS implementation relies on:
- `tls-eio` (>= 0.17.0): TLS layer for Eio
- `ca-certs` (>= 0.2.0): System CA certificate loading
- `x509` (>= 0.16.0): X.509 certificate handling
- `domain-name` (>= 0.4.0): DNS name handling for SNI

Install all dependencies:
```bash
opam install tls-eio ca-certs x509 domain-name
```

## Troubleshooting

### "TLS auth error: ..."
- System CA certificates not found or invalid
- Solution: Install ca-certificates package or configure custom authenticator

### "Invalid hostname: ..."
- Hostname cannot be parsed as valid domain name
- Solution: Use valid FQDN or IP address

### Certificate verification failures
- Server certificate not trusted by system CAs
- Solution: Add CA to system trust store or use custom authenticator

### Type mismatch errors
- TCP and TLS flows have incompatible Eio types
- Solution: Use separate `connect_tls` function for TLS connections

## Future Work

- [ ] Unified connection interface supporting both TCP and TLS
- [ ] Custom certificate validation callbacks
- [ ] Client certificate authentication
- [ ] TLS configuration options (cipher suites, min/max TLS version)
- [ ] Connection pooling with mixed TCP/TLS support

## References

- [Neo4j Bolt Protocol](https://neo4j.com/docs/bolt/current/)
- [Eio Documentation](https://github.com/ocaml-multicore/eio)
- [OCaml-TLS](https://github.com/mirleft/ocaml-tls)
- [Neo4j TLS Configuration](https://neo4j.com/docs/operations-manual/current/security/ssl-framework/)

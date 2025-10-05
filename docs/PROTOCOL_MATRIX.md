Bolt Protocol Matrix and Driver Strategy

Purpose
- Classify negotiated Bolt versions and define which messages and flows to use for parity with hasbolt while targeting Neo4j 5 via Docker.

Version Encoding (matches hasbolt semantics)
- Server replies 32-bit version where major is in the least-significant byte and minor is in the next byte.
- Example: `0x00000104` means v4.1 (major=4, minor=1). `0x00000005` means v5.x (major=5, minor=0).

Classification
- v1/v2: INIT, RUN, PULL_ALL, DISCARD_ALL, RESET, ACK_FAILURE
- v3/v4.x: HELLO (credentials inline), RUN, PULL, DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE
- v5.x: HELLO (no credentials), LOGON/LOGOFF, RUN, PULL, DISCARD, BEGIN/COMMIT/ROLLBACK, RESET, GOODBYE

Driver Strategy
- Negotiate highest available in [5.x, 4.x, 3.x, 2, 1].
- If v5.x: use HELLO -> LOGON (basic), LOGOFF -> GOODBYE.
- If v4.x or v3: use HELLO with credentials (basic), GOODBYE on close.
- If v1/2: use INIT with credentials; ACK_FAILURE recovery; PULL_ALL/DISCARD_ALL.

Message Signatures (as per hasbolt constants)
- Requests: INIT/HELLO=0x01, RUN=0x10, RESET=0x0F, DISCARD(_ALL)=0x2F, PULL(_ALL)=0x3F, GOODBYE=0x02, BEGIN=0x11, COMMIT=0x12, ROLLBACK=0x13.
- Responses: SUCCESS=0x70, RECORD=0x71, IGNORED=0x7E, FAILURE=0x7F.

Mapping of Features to Versions
- Queries: RUN + (PULL_ALL|PULL) available across versions.
- Transactions: explicit messages BEGIN/COMMIT/ROLLBACK in v3+; in v1/2, fallback to textual statements (BEGIN/COMMIT/ROLLBACK).
- Reset/Recovery: RESET in all; ACK_FAILURE only in v1/2.
- Auth: HELLO with credentials in v3/4; LOGON in v5.

Testing Against Docker Neo4j 5
- Expect major=5; accept any non-zero negotiated version in integration handshake.
- Future tests will verify HELLO/LOGON and RUN/PULL flows under v5 classification.


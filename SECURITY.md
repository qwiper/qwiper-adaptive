# Security

The built-in probe reads aggregate Android resource characteristics locally.
It does not collect device identifiers, transmit data, persist observations,
or request runtime permissions. Hosts are responsible for any telemetry they
add around the library. Do not log custom reader errors containing private data.

For a suspected vulnerability, contact the maintainer through the hosting
repository's private vulnerability reporting feature when available. If no
private channel is configured, open an issue asking for a private contact
without including exploit details, credentials or user data.

Before the first public release, the maintainer must configure that private
reporting channel and identify who will receive reports. No response-time
commitment or independently audited security status is claimed by this package.

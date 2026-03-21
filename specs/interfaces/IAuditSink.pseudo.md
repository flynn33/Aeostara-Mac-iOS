# IAuditSink Interface

Abstract audit trail interface for recording and retrieving healing events.

## Methods

### record(event)

Persist an audit event to the trail.

**Parameters:**
- `event` (AuditEvent) — the event to record

### getEvents() → List[AuditEvent]

Retrieve all recorded audit events.

**Returns:** list of AuditEvent — all events in the trail, in chronological order

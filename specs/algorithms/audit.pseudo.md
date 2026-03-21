# Audit Trail

Append-only JSON Lines (.jsonl) audit logging. Each line is a self-contained AuditEvent serialized as JSON.

## record(event)

```
FUNCTION record(event):
  line ← serializeJSON(event)
  fileSystem.appendFile(auditPath, line + "\n")
```

## createEvent(type, configFile, details) → AuditEvent

```
FUNCTION createEvent(type, configFile, details) → AuditEvent:
  RETURN AuditEvent(
    eventID = generateUUID(),
    type = type,
    timestamp = currentISO8601(),
    configFile = configFile,
    details = details
  )
```

## getEvents() → List[AuditEvent]

```
FUNCTION getEvents() → List[AuditEvent]:
  content ← fileSystem.readFile(auditPath)
  lines ← split(content, "\n")
  events ← empty list

  FOR EACH line IN lines:
    IF line is NOT empty:
      event ← deserializeJSON(line) as AuditEvent
      events.add(event)

  RETURN events
```

## File Format

The audit trail is stored as JSON Lines (`.jsonl`):
- One JSON object per line
- Each line is a complete, self-contained AuditEvent
- Append-only — events are never modified or deleted
- Streamable — can be read line-by-line without parsing the entire file

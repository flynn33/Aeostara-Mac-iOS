# JSON Path Operations

Dot-path utilities for getting, setting, checking existence, flattening, and unflattening nested JSON objects.

## get(obj, dotPath) → value

```
FUNCTION get(obj, dotPath) → value:
  keys ← split(dotPath, ".")
  current ← obj

  FOR EACH key IN keys:
    IF current is NOT an object OR key NOT IN current:
      RETURN null
    current ← current[key]

  RETURN current
```

## set(obj, dotPath, value) → mutated obj

```
FUNCTION set(obj, dotPath, value):
  keys ← split(dotPath, ".")
  current ← obj

  FOR i FROM 0 TO length(keys) - 2:
    key ← keys[i]
    IF key NOT IN current OR current[key] is NOT an object:
      current[key] ← empty object
    current ← current[key]

  current[keys[last]] ← value
```

## exists(obj, dotPath) → Boolean

```
FUNCTION exists(obj, dotPath) → Boolean:
  keys ← split(dotPath, ".")
  current ← obj

  FOR EACH key IN keys:
    IF current is NOT an object OR key NOT IN current:
      RETURN false
    current ← current[key]

  RETURN true
```

## flatten(obj, prefix) → Map[string, value]

```
FUNCTION flatten(obj, prefix = "") → Map:
  result ← empty map

  FOR EACH (key, value) IN obj:
    fullPath ← IF prefix is empty THEN key ELSE prefix + "." + key

    IF value is an object AND NOT an array:
      result.merge(flatten(value, fullPath))
    ELSE:
      result[fullPath] ← value

  RETURN result
```

## unflatten(flatMap) → nested obj

```
FUNCTION unflatten(flatMap) → object:
  result ← empty object

  FOR EACH (dotPath, value) IN flatMap:
    set(result, dotPath, value)

  RETURN result
```

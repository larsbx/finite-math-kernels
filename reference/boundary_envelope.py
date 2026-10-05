"""Reference semantics of schemas/polyglot-boundary-envelope-v1.json: a closed, fail-closed validator.

It understands exactly the JSON Schema keywords that contract uses. Any other
keyword anywhere in the schema is refused rather than ignored, whatever the
value, so a schema change can never make the validator silently more permissive.
"""

from __future__ import annotations

import re

KEYWORDS = {"$schema", "$id", "title", "type", "additionalProperties", "required", "properties",
            "const", "enum", "minLength", "pattern"}
TYPES = {"object": dict, "string": str}


def unsupported(schema: dict, path: str = "$") -> str | None:
    """The first schema location using a keyword this validator does not implement, if any."""
    unknown = set(schema) - KEYWORDS
    if unknown:
        return f"{path}: unsupported schema keywords {sorted(unknown)}"
    return next((r for k, sub in schema.get("properties", {}).items()
                 for r in [unsupported(sub, f"{path}.{k}")] if r), None)


def violation(schema: dict, value, path: str = "$") -> str | None:
    """The first reason value fails a schema that uses only supported keywords, if any."""
    if "type" in schema and not isinstance(value, TYPES[schema["type"]]):
        return f"{path}: expected {schema['type']}"
    if "const" in schema and value != schema["const"]:
        return f"{path}: expected {schema['const']!r}"
    if "enum" in schema and value not in schema["enum"]:
        return f"{path}: not one of {schema['enum']}"
    if "minLength" in schema and len(value) < schema["minLength"]:
        return f"{path}: shorter than {schema['minLength']}"
    if "pattern" in schema and not re.search(schema["pattern"], value):
        return f"{path}: does not match {schema['pattern']}"
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        missing = [k for k in schema.get("required", []) if k not in value]
        if missing:
            return f"{path}: missing {missing}"
        if schema.get("additionalProperties") is False and set(value) - set(properties):
            return f"{path}: unknown fields {sorted(set(value) - set(properties))}"
        return next((r for k, sub in properties.items() if k in value
                     for r in [violation(sub, value[k], f"{path}.{k}")] if r), None)
    return None


def refusal(schema: dict, value) -> str | None:
    """None if value satisfies schema; otherwise why not. An unsupported schema refuses every value."""
    return unsupported(schema) or violation(schema, value)

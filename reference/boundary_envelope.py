"""Reference semantics of schemas/polyglot-boundary-envelope-v1.json: a closed, fail-closed validator.

It understands exactly the JSON Schema keywords that contract uses. Any other
keyword is refused rather than ignored, so a schema change can never make the
validator silently more permissive.
"""

from __future__ import annotations

import re

ANNOTATIONS = {"$schema", "$id", "title"}
TYPES = {"object": dict, "string": str}


def refusal(schema: dict, value, path: str = "$") -> str | None:
    """None if value satisfies schema; otherwise the first reason it does not."""
    unknown = set(schema) - ANNOTATIONS - {"type", "additionalProperties", "required", "properties",
                                            "const", "enum", "minLength", "pattern"}
    if unknown:
        return f"{path}: unsupported schema keywords {sorted(unknown)}"
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
                     for r in [refusal(sub, value[k], f"{path}.{k}")] if r), None)
    return None

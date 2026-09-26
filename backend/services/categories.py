"""Canonical product category vocabulary for HunarSathi.

Single source of truth shared by buyer filtering, RFQ parsing, pricing and
AI listing generation so exact-match Firestore filters
(`products.category == X`) do not silently return empty results.

Canonical set (frozen for the SIH demo catalog):
    Textiles, Pottery, Jewellery, Embroidery, Wood Craft,
    Leather, Painting, Metal Craft, Other

Legacy spellings (Jewelry/Woodwork/Metalwork/Accessories/Stonework/...) are
mapped to canonical values via :func:`normalize_category` so existing
documents keep working. No database migration is required.
"""

CANONICAL_CATEGORIES = [
    "Textiles",
    "Pottery",
    "Jewellery",
    "Embroidery",
    "Wood Craft",
    "Leather",
    "Painting",
    "Metal Craft",
    "Other",
]

_CANONICAL_LOWER = {c.lower(): c for c in CANONICAL_CATEGORIES}

# Lower-cased legacy spellings -> canonical category.
LEGACY_CATEGORY_ALIASES = {
    "jewelry": "Jewellery",
    "woodwork": "Wood Craft",
    "wood work": "Wood Craft",
    "metalwork": "Metal Craft",
    "metal work": "Metal Craft",
    "accessories": "Other",
    "accessory": "Other",
    "stonework": "Other",
    "basketry": "Other",
    "handicraft": "Other",
}


def is_canonical_category(value) -> bool:
    """Return True if *value* is exactly one of the canonical categories."""
    return isinstance(value, str) and value.strip().lower() in _CANONICAL_LOWER


def normalize_category(value, default: str = "Other") -> str:
    """Map *value* to its canonical category spelling.

    - Canonical values pass through with canonical casing.
    - Known legacy spellings map to their canonical equivalent.
    - Unknown non-empty values pass through untouched (e.g. the historical
      "Uncategorized" default) so stored data is never silently rewritten
      into something unexpected.
    - None/empty values return *default*.
    """
    if value is None:
        return default
    text = str(value).strip()
    if not text:
        return default
    lower = text.lower()
    if lower in _CANONICAL_LOWER:
        return _CANONICAL_LOWER[lower]
    if lower in LEGACY_CATEGORY_ALIASES:
        return LEGACY_CATEGORY_ALIASES[lower]
    return text


def category_aliases_for(canonical: str) -> list:
    """Return all stored spellings that normalize to *canonical*.

    Used for alias-aware read compatibility without migrating Firestore.
    """
    target = normalize_category(canonical)
    aliases = [c for c in CANONICAL_CATEGORIES if normalize_category(c) == target]
    for legacy, mapped in LEGACY_CATEGORY_ALIASES.items():
        if mapped == target and legacy not in [a.lower() for a in aliases]:
            # Return a display-friendly legacy form for debugging; matching
            # itself is done via normalize_category, not this list.
            aliases.append(legacy)
    return aliases

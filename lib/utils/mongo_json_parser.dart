/// Helpers for parsing the JSON-ish text users type into the document and
/// aggregation editors.
///
/// MongoDB Compass accepts mongosh-style constructors such as
/// `ObjectId("...")` so a value can be typed as an ObjectId instead of a plain
/// string. The app's parsers are JSON-based, so these constructors are first
/// rewritten to their Extended JSON equivalents (`{"$oid": "..."}`), which the
/// engines already understand.
library;

/// Rewrites mongosh constructors in [text] to Extended JSON.
///
/// Supported:
/// * `ObjectId("...")` / `new ObjectId("...")` → `{"$oid": "..."}`
/// * `ISODate("...")` / `new Date("...")` → `{"$date": "..."}`
///
/// Everything else is left untouched.
String preprocessMongoJson(String text) {
  var out = text;

  out = out.replaceAllMapped(
    RegExp(r'''(?:new\s+)?ObjectId\s*\(\s*(["'])([^"']*)\1\s*\)'''),
    (m) => '{"\$oid": "${m[2]}"}',
  );

  out = out.replaceAllMapped(
    RegExp(r'''(?:ISODate|new\s+Date)\s*\(\s*(["'])([^"']*)\1\s*\)'''),
    (m) => '{"\$date": "${m[2]}"}',
  );

  return out;
}

import 'dart:convert';
import 'dart:math';

import '../models/mongo_models.dart';
import '../utils/mongo_json_parser.dart';

/// Dart implementation of sample data and Mongo engine service
/// Mirrors src/services/sampleData.ts and mongoEngine.ts.
/// Local, in-memory implementation of the Mongo engine: the bundled sample
/// data plus all of the query, aggregation and mutation logic. It intentionally
/// mirrors the synchronous API of the React `mongoEngine` so the widgets can
/// read state during `build`; [RealMongoService] extends it to serve data from
/// an actual MongoDB server.
class LocalMongoEngine {
  /// The default engine, preloaded with the bundled sample datasets
  /// (`library`, `social_networks`).
  static final LocalMongoEngine instance = LocalMongoEngine.seeded();

  static final Random _random = Random();

  /// In-memory representation of the databases this engine serves.
  List<MongoDatabase> databases = [];

  LocalMongoEngine();

  /// Creates an engine preloaded with the bundled sample data.
  factory LocalMongoEngine.seeded() => LocalMongoEngine()..seedSampleData();

  /// Seeds the bundled sample datasets from `sample_library.json` and
  /// `sample_social_network.json` in the repo root.
  ///
  /// The JSON files use MongoDB extended JSON (`{ "$oid": ... }`,
  /// `{ "$date": ... }`); here ObjectIds keep the BSON type ([MongoObjectId],
  /// built from the 24-char hex strings via [_typedSeedDocs]) and dates are
  /// ISO-8601 strings — the same shape [RealMongoService] applies to real
  /// server documents.
  /// The bundled JSON expresses ObjectIds as 24-char hex strings; the in-memory
  /// engine keeps the BSON type ([MongoObjectId]) instead, so the editors can
  /// show `ObjectId("...")` and distinguish it from a plain string.
  static List<MongoDocument> _typedSeedDocs(List<MongoDocument> docs) => [
    for (final doc in docs)
      MongoDocument.fromMap(_typedSeedValue(doc.data) as Map<String, dynamic>),
  ];

  static dynamic _typedSeedValue(dynamic value) {
    if (value is String &&
        value.length == 24 &&
        RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value)) {
      return MongoObjectId(value);
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _typedSeedValue(entry.value),
      };
    }
    if (value is List) return value.map(_typedSeedValue).toList();
    return value;
  }

  void seedSampleData() {
    final books = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a001",
        "title": "The Silent Horizon",
        "author": "Elena Rostova",
        "isbn": "978-3-16-148410-0",
        "published_year": 2019,
        "publisher_id": "60c72b2f9b1d8b0015f8a010",
        "genre_ids": ["60c72b2f9b1d8b0015f8a020", "60c72b2f9b1d8b0015f8a021"],
        "copies_available": 4,
        "rating": 4.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a002",
        "title": "Algorithms of the Mind",
        "author": "Dr. Marcus Vance",
        "isbn": "978-1-23-456789-7",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a011",
        "genre_ids": ["60c72b2f9b1d8b0015f8a022"],
        "copies_available": 2,
        "rating": 4.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a003",
        "title": "Atlas of Quiet Stars",
        "author": "Iris Bellamy",
        "isbn": "978-1-10-100000-0",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a010",
        "genre_ids": ["60c72b2f9b1d8b0015f8a020", "60c72b2f9b1d8b0015f8a021"],
        "copies_available": 1,
        "rating": 3.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a004",
        "title": "The Cartographer's Debt",
        "author": "Tomas Reyes",
        "isbn": "978-1-11-100137-1",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a011",
        "genre_ids": ["60c72b2f9b1d8b0015f8a027", "60c72b2f9b1d8b0015f8a028"],
        "copies_available": 2,
        "rating": 3.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a005",
        "title": "Signals from the Deep",
        "author": "Nadia Haddad",
        "isbn": "978-1-12-100274-2",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a012",
        "genre_ids": ["60c72b2f9b1d8b0015f8a034", "60c72b2f9b1d8b0015f8a035"],
        "copies_available": 3,
        "rating": 3.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a006",
        "title": "A Field Guide to Static",
        "author": "Owen Marsh",
        "isbn": "978-1-13-100411-3",
        "published_year": 2018,
        "publisher_id": "60c72b2f9b1d8b0015f8a013",
        "genre_ids": ["60c72b2f9b1d8b0015f8a041", "60c72b2f9b1d8b0015f8a042"],
        "copies_available": 4,
        "rating": 3.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a007",
        "title": "The Last Analog Summer",
        "author": "Priya Raman",
        "isbn": "978-1-14-100548-4",
        "published_year": 2020,
        "publisher_id": "60c72b2f9b1d8b0015f8a014",
        "genre_ids": ["60c72b2f9b1d8b0015f8a048", "60c72b2f9b1d8b0015f8a049"],
        "copies_available": 5,
        "rating": 3.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a008",
        "title": "Northern Lights Protocol",
        "author": "Jonas Keller",
        "isbn": "978-1-15-100685-5",
        "published_year": 2021,
        "publisher_id": "60c72b2f9b1d8b0015f8a015",
        "genre_ids": ["60c72b2f9b1d8b0015f8a055", "60c72b2f9b1d8b0015f8a056"],
        "copies_available": 6,
        "rating": 4.0,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a009",
        "title": "Glass Orchards",
        "author": "Amelia Frost",
        "isbn": "978-1-16-100822-6",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a016",
        "genre_ids": ["60c72b2f9b1d8b0015f8a062", "60c72b2f9b1d8b0015f8a063"],
        "copies_available": 7,
        "rating": 4.1,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a010",
        "title": "Notes on Tiny Machines",
        "author": "Rafael Costa",
        "isbn": "978-1-17-100959-7",
        "published_year": 2023,
        "publisher_id": "60c72b2f9b1d8b0015f8a017",
        "genre_ids": ["60c72b2f9b1d8b0015f8a069", "60c72b2f9b1d8b0015f8a020"],
        "copies_available": 8,
        "rating": 4.2,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a011",
        "title": "The Weight of Paper Maps",
        "author": "Lena Okafor",
        "isbn": "978-1-18-101096-8",
        "published_year": 2024,
        "publisher_id": "60c72b2f9b1d8b0015f8a018",
        "genre_ids": ["60c72b2f9b1d8b0015f8a026", "60c72b2f9b1d8b0015f8a027"],
        "copies_available": 9,
        "rating": 4.3,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a012",
        "title": "Echoes in the Server Room",
        "author": "Miles Harding",
        "isbn": "978-1-19-101233-9",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a019",
        "genre_ids": ["60c72b2f9b1d8b0015f8a033", "60c72b2f9b1d8b0015f8a034"],
        "copies_available": 10,
        "rating": 4.4,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a013",
        "title": "Winter Algorithms",
        "author": "Sofia Lindqvist",
        "isbn": "978-1-20-101370-0",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a020",
        "genre_ids": ["60c72b2f9b1d8b0015f8a040", "60c72b2f9b1d8b0015f8a041"],
        "copies_available": 11,
        "rating": 4.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a014",
        "title": "The Ocean Between Us",
        "author": "Ethan Park",
        "isbn": "978-1-21-101507-1",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a021",
        "genre_ids": ["60c72b2f9b1d8b0015f8a047", "60c72b2f9b1d8b0015f8a048"],
        "copies_available": 12,
        "rating": 4.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a015",
        "title": "Small Gods of Silicon",
        "author": "Clara Mensah",
        "isbn": "978-1-22-101644-2",
        "published_year": 2018,
        "publisher_id": "60c72b2f9b1d8b0015f8a022",
        "genre_ids": ["60c72b2f9b1d8b0015f8a054", "60c72b2f9b1d8b0015f8a055"],
        "copies_available": 1,
        "rating": 4.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a016",
        "title": "A Theory of Soft Edges",
        "author": "Hugo Ferreira",
        "isbn": "978-1-23-101781-3",
        "published_year": 2020,
        "publisher_id": "60c72b2f9b1d8b0015f8a023",
        "genre_ids": ["60c72b2f9b1d8b0015f8a061", "60c72b2f9b1d8b0015f8a062"],
        "copies_available": 2,
        "rating": 4.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a017",
        "title": "Broken Compasses",
        "author": "Yuki Tanaka",
        "isbn": "978-1-24-101918-4",
        "published_year": 2021,
        "publisher_id": "60c72b2f9b1d8b0015f8a024",
        "genre_ids": ["60c72b2f9b1d8b0015f8a068", "60c72b2f9b1d8b0015f8a069"],
        "copies_available": 3,
        "rating": 4.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a018",
        "title": "The Hidden Ledger",
        "author": "Miriam Doyle",
        "isbn": "978-1-25-102055-5",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a025",
        "genre_ids": ["60c72b2f9b1d8b0015f8a025", "60c72b2f9b1d8b0015f8a026"],
        "copies_available": 4,
        "rating": 5.0,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a019",
        "title": "Rainfall in Redwood City",
        "author": "Andrei Popescu",
        "isbn": "978-1-26-102192-6",
        "published_year": 2023,
        "publisher_id": "60c72b2f9b1d8b0015f8a026",
        "genre_ids": ["60c72b2f9b1d8b0015f8a032", "60c72b2f9b1d8b0015f8a033"],
        "copies_available": 5,
        "rating": 3.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a020",
        "title": "Anatomy of a Search",
        "author": "Zoe Bennett",
        "isbn": "978-1-27-102329-7",
        "published_year": 2024,
        "publisher_id": "60c72b2f9b1d8b0015f8a027",
        "genre_ids": ["60c72b2f9b1d8b0015f8a039", "60c72b2f9b1d8b0015f8a040"],
        "copies_available": 6,
        "rating": 3.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a021",
        "title": "The Slow Network",
        "author": "Samir Haddad",
        "isbn": "978-1-28-102466-8",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a028",
        "genre_ids": ["60c72b2f9b1d8b0015f8a046", "60c72b2f9b1d8b0015f8a047"],
        "copies_available": 7,
        "rating": 3.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a022",
        "title": "Pages of Blue Smoke",
        "author": "Grace Whitfield",
        "isbn": "978-1-29-102603-9",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a029",
        "genre_ids": ["60c72b2f9b1d8b0015f8a053", "60c72b2f9b1d8b0015f8a054"],
        "copies_available": 8,
        "rating": 3.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a023",
        "title": "Machine Learning at Dawn",
        "author": "Lucas Meyer",
        "isbn": "978-1-30-102740-0",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a030",
        "genre_ids": ["60c72b2f9b1d8b0015f8a060", "60c72b2f9b1d8b0015f8a061"],
        "copies_available": 9,
        "rating": 3.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a024",
        "title": "The Quiet Index",
        "author": "Aisha Rahman",
        "isbn": "978-1-31-102877-1",
        "published_year": 2018,
        "publisher_id": "60c72b2f9b1d8b0015f8a031",
        "genre_ids": ["60c72b2f9b1d8b0015f8a067", "60c72b2f9b1d8b0015f8a068"],
        "copies_available": 10,
        "rating": 4.0,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a025",
        "title": "Lost in the Metadata",
        "author": "Felix Novak",
        "isbn": "978-1-32-103014-2",
        "published_year": 2020,
        "publisher_id": "60c72b2f9b1d8b0015f8a032",
        "genre_ids": ["60c72b2f9b1d8b0015f8a024", "60c72b2f9b1d8b0015f8a025"],
        "copies_available": 11,
        "rating": 4.1,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a026",
        "title": "Cities Without Clocks",
        "author": "Colette Dubois",
        "isbn": "978-1-33-103151-3",
        "published_year": 2021,
        "publisher_id": "60c72b2f9b1d8b0015f8a033",
        "genre_ids": ["60c72b2f9b1d8b0015f8a031", "60c72b2f9b1d8b0015f8a032"],
        "copies_available": 12,
        "rating": 4.2,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a027",
        "title": "The Grammar of Trees",
        "author": "Ravi Menon",
        "isbn": "978-1-34-103288-4",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a034",
        "genre_ids": ["60c72b2f9b1d8b0015f8a038", "60c72b2f9b1d8b0015f8a039"],
        "copies_available": 1,
        "rating": 4.3,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a028",
        "title": "After the Last Backup",
        "author": "Hannah Wolfe",
        "isbn": "978-1-35-103425-5",
        "published_year": 2023,
        "publisher_id": "60c72b2f9b1d8b0015f8a035",
        "genre_ids": ["60c72b2f9b1d8b0015f8a045", "60c72b2f9b1d8b0015f8a046"],
        "copies_available": 2,
        "rating": 4.4,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a029",
        "title": "Satellites of Mercury",
        "author": "Pedro Alvarez",
        "isbn": "978-1-36-103562-6",
        "published_year": 2024,
        "publisher_id": "60c72b2f9b1d8b0015f8a036",
        "genre_ids": ["60c72b2f9b1d8b0015f8a052", "60c72b2f9b1d8b0015f8a053"],
        "copies_available": 3,
        "rating": 4.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a030",
        "title": "A Pocketful of Frequencies",
        "author": "Ingrid Sorensen",
        "isbn": "978-1-37-103699-7",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a037",
        "genre_ids": ["60c72b2f9b1d8b0015f8a059", "60c72b2f9b1d8b0015f8a060"],
        "copies_available": 4,
        "rating": 4.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a031",
        "title": "The Wooden Terminal",
        "author": "Malik Johnson",
        "isbn": "978-1-38-103836-8",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a038",
        "genre_ids": ["60c72b2f9b1d8b0015f8a066", "60c72b2f9b1d8b0015f8a067"],
        "copies_available": 5,
        "rating": 4.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a032",
        "title": "Charting the Unseen",
        "author": "Elena Vargas",
        "isbn": "978-1-39-103973-9",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a039",
        "genre_ids": ["60c72b2f9b1d8b0015f8a023", "60c72b2f9b1d8b0015f8a024"],
        "copies_available": 6,
        "rating": 4.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a033",
        "title": "Every Circuit Has a Coast",
        "author": "Theo Ashford",
        "isbn": "978-1-40-104110-0",
        "published_year": 2018,
        "publisher_id": "60c72b2f9b1d8b0015f8a040",
        "genre_ids": ["60c72b2f9b1d8b0015f8a030", "60c72b2f9b1d8b0015f8a031"],
        "copies_available": 7,
        "rating": 4.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a034",
        "title": "Memoirs of a Middle Node",
        "author": "Camille Laurent",
        "isbn": "978-1-41-104247-1",
        "published_year": 2020,
        "publisher_id": "60c72b2f9b1d8b0015f8a041",
        "genre_ids": ["60c72b2f9b1d8b0015f8a037", "60c72b2f9b1d8b0015f8a038"],
        "copies_available": 8,
        "rating": 5.0,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a035",
        "title": "The Shape of Cache",
        "author": "Dmitri Volkov",
        "isbn": "978-1-42-104384-2",
        "published_year": 2021,
        "publisher_id": "60c72b2f9b1d8b0015f8a042",
        "genre_ids": ["60c72b2f9b1d8b0015f8a044", "60c72b2f9b1d8b0015f8a045"],
        "copies_available": 9,
        "rating": 3.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a036",
        "title": "Windward",
        "author": "Nora Fields",
        "isbn": "978-1-43-104521-3",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a043",
        "genre_ids": ["60c72b2f9b1d8b0015f8a051", "60c72b2f9b1d8b0015f8a052"],
        "copies_available": 10,
        "rating": 3.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a037",
        "title": "In Praise of Narrow Streets",
        "author": "Kwame Asante",
        "isbn": "978-1-44-104658-4",
        "published_year": 2023,
        "publisher_id": "60c72b2f9b1d8b0015f8a044",
        "genre_ids": ["60c72b2f9b1d8b0015f8a058", "60c72b2f9b1d8b0015f8a059"],
        "copies_available": 11,
        "rating": 3.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a038",
        "title": "The Decimal Garden",
        "author": "Julia Rossi",
        "isbn": "978-1-45-104795-5",
        "published_year": 2024,
        "publisher_id": "60c72b2f9b1d8b0015f8a045",
        "genre_ids": ["60c72b2f9b1d8b0015f8a065", "60c72b2f9b1d8b0015f8a066"],
        "copies_available": 12,
        "rating": 3.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a039",
        "title": "Night Shift at the Archive",
        "author": "Omar Farouk",
        "isbn": "978-1-46-104932-6",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a046",
        "genre_ids": ["60c72b2f9b1d8b0015f8a022", "60c72b2f9b1d8b0015f8a023"],
        "copies_available": 1,
        "rating": 3.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a040",
        "title": "Threadbare Universes",
        "author": "Beatrice Clarke",
        "isbn": "978-1-47-105069-7",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a047",
        "genre_ids": ["60c72b2f9b1d8b0015f8a029", "60c72b2f9b1d8b0015f8a030"],
        "copies_available": 2,
        "rating": 4.0,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a041",
        "title": "Terraforming the Page",
        "author": "Arjun Desai",
        "isbn": "978-1-48-105206-8",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a048",
        "genre_ids": ["60c72b2f9b1d8b0015f8a036", "60c72b2f9b1d8b0015f8a037"],
        "copies_available": 3,
        "rating": 4.1,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a042",
        "title": "Constellations for Beginners",
        "author": "Freya Nilsson",
        "isbn": "978-1-49-105343-9",
        "published_year": 2018,
        "publisher_id": "60c72b2f9b1d8b0015f8a049",
        "genre_ids": ["60c72b2f9b1d8b0015f8a043", "60c72b2f9b1d8b0015f8a044"],
        "copies_available": 4,
        "rating": 4.2,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a043",
        "title": "The Paper Telescope",
        "author": "Gabriel Santos",
        "isbn": "978-1-50-105480-0",
        "published_year": 2020,
        "publisher_id": "60c72b2f9b1d8b0015f8a050",
        "genre_ids": ["60c72b2f9b1d8b0015f8a050", "60c72b2f9b1d8b0015f8a051"],
        "copies_available": 5,
        "rating": 4.3,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a044",
        "title": "Salt and Static",
        "author": "Leila Karim",
        "isbn": "978-1-51-105617-1",
        "published_year": 2021,
        "publisher_id": "60c72b2f9b1d8b0015f8a051",
        "genre_ids": ["60c72b2f9b1d8b0015f8a057", "60c72b2f9b1d8b0015f8a058"],
        "copies_available": 6,
        "rating": 4.4,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a045",
        "title": "A History of Small Screens",
        "author": "Victor Chen",
        "isbn": "978-1-52-105754-2",
        "published_year": 2022,
        "publisher_id": "60c72b2f9b1d8b0015f8a052",
        "genre_ids": ["60c72b2f9b1d8b0015f8a064", "60c72b2f9b1d8b0015f8a065"],
        "copies_available": 7,
        "rating": 4.5,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a046",
        "title": "The Glasshouse Cipher",
        "author": "Rosa Iglesias",
        "isbn": "978-1-53-105891-3",
        "published_year": 2023,
        "publisher_id": "60c72b2f9b1d8b0015f8a053",
        "genre_ids": ["60c72b2f9b1d8b0015f8a021", "60c72b2f9b1d8b0015f8a022"],
        "copies_available": 8,
        "rating": 4.6,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a047",
        "title": "Between Two Packets",
        "author": "Emil Berg",
        "isbn": "978-1-54-106028-4",
        "published_year": 2024,
        "publisher_id": "60c72b2f9b1d8b0015f8a054",
        "genre_ids": ["60c72b2f9b1d8b0015f8a028", "60c72b2f9b1d8b0015f8a029"],
        "copies_available": 9,
        "rating": 4.7,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a048",
        "title": "Moons of the Inner World",
        "author": "Talia Cohen",
        "isbn": "978-1-55-106165-5",
        "published_year": 2015,
        "publisher_id": "60c72b2f9b1d8b0015f8a055",
        "genre_ids": ["60c72b2f9b1d8b0015f8a035", "60c72b2f9b1d8b0015f8a036"],
        "copies_available": 10,
        "rating": 4.8,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a049",
        "title": "The Lantern Index",
        "author": "Nikhil Rao",
        "isbn": "978-1-56-106302-6",
        "published_year": 2016,
        "publisher_id": "60c72b2f9b1d8b0015f8a056",
        "genre_ids": ["60c72b2f9b1d8b0015f8a042", "60c72b2f9b1d8b0015f8a043"],
        "copies_available": 11,
        "rating": 4.9,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "title": "Where the Data Ends",
        "author": "Ada Svensson",
        "isbn": "978-1-57-106439-7",
        "published_year": 2017,
        "publisher_id": "60c72b2f9b1d8b0015f8a057",
        "genre_ids": ["60c72b2f9b1d8b0015f8a049", "60c72b2f9b1d8b0015f8a050"],
        "copies_available": 12,
        "rating": 5.0,
      }),
    ];

    final publishers = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a010",
        "name": "Apex Academic Press",
        "city": "Boston",
        "country": "USA",
        "founded_year": 1985,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a011",
        "name": "Vanguard Publishing House",
        "city": "London",
        "country": "UK",
        "founded_year": 2001,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a012",
        "name": "Northwind House",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1900,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a013",
        "name": "Beacon & Slate",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1913,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a014",
        "name": "Meridian Press",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1926,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a015",
        "name": "Hollow Oak Books",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1939,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a016",
        "name": "Cobalt Publishing",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1952,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a017",
        "name": "Lantern Hill",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1965,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a018",
        "name": "Verity Editions",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1978,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a019",
        "name": "Aster Publishing",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1991,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a020",
        "name": "Copperline Press",
        "city": "Portland",
        "country": "USA",
        "founded_year": 2004,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a021",
        "name": "Orchard House",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 2017,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a022",
        "name": "Bluepeak Media",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1905,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a023",
        "name": "Tessellate Books",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1918,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a024",
        "name": "Redwood Academic",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1931,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a025",
        "name": "Halcyon Press",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1944,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a026",
        "name": "Ironbark Publishing",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1957,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a027",
        "name": "Summit Editions",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1970,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a028",
        "name": "Willow & Wren",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1983,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a029",
        "name": "Atlas Grove",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1996,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a030",
        "name": "Pilgrim Press",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 2009,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a031",
        "name": "Cinder Publishing",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 2022,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a032",
        "name": "Brightwater Books",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1910,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a033",
        "name": "Quarterly House",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1923,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a034",
        "name": "Mosaic Press",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1936,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a035",
        "name": "Fieldstone Media",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1949,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a036",
        "name": "Paper Lantern Books",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1962,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a037",
        "name": "Granite Editions",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1975,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a038",
        "name": "Southgate Publishing",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1988,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a039",
        "name": "Ember House",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 2001,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a040",
        "name": "Harborlight Press",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 2014,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a041",
        "name": "Vellum & Co",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1902,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a042",
        "name": "Juniper Books",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1915,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a043",
        "name": "Keystone Media",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1928,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a044",
        "name": "Silverfern Press",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1941,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a045",
        "name": "Canopy Editions",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1954,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a046",
        "name": "Northstar Books",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1967,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a047",
        "name": "Meadowlark Press",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1980,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a048",
        "name": "Solstice Publishing",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1993,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a049",
        "name": "Bramble House",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 2006,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "name": "Cardinal Press",
        "city": "Portland",
        "country": "USA",
        "founded_year": 2019,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a051",
        "name": "Driftwood Media",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1907,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a052",
        "name": "Foundry Books",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1920,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a053",
        "name": "Larkspur Editions",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 1933,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a054",
        "name": "Palisade Press",
        "city": "Lisbon",
        "country": "Portugal",
        "founded_year": 1946,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a055",
        "name": "Tidepool Publishing",
        "city": "Kyoto",
        "country": "Japan",
        "founded_year": 1959,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a056",
        "name": "Westwind House",
        "city": "Portland",
        "country": "USA",
        "founded_year": 1972,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a057",
        "name": "Arrowhead Books",
        "city": "Berlin",
        "country": "Germany",
        "founded_year": 1985,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a058",
        "name": "Quill & Compass",
        "city": "Toronto",
        "country": "Canada",
        "founded_year": 1998,
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a059",
        "name": "Morrowfield Press",
        "city": "Melbourne",
        "country": "Australia",
        "founded_year": 2011,
      }),
    ];

    final genres = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a020",
        "name": "Science Fiction",
        "description":
            "Speculative fiction dealing with imaginative and futuristic concepts.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a021",
        "name": "Mystery",
        "description":
            "Fiction revolving around the solution of a crime or secrets.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a022",
        "name": "Technology",
        "description":
            "Non-fiction works discussing computing, artificial intelligence, and software.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a023",
        "name": "Adventure",
        "description":
            "Journeys, exploration, and challenges in unfamiliar settings.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a024",
        "name": "Biography",
        "description": "Accounts of real lives, told in narrative form.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a025",
        "name": "Contemporary Fiction",
        "description": "Modern stories grounded in everyday life.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a026",
        "name": "Cryptography",
        "description": "The study of hidden messages and secure communication.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a027",
        "name": "Data Visualization",
        "description": "Communicating information through charts and maps.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a028",
        "name": "Design",
        "description":
            "The practice of shaping products, spaces, and experiences.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a029",
        "name": "Distributed Systems",
        "description": "Software that runs across many coordinated machines.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a030",
        "name": "Economics",
        "description": "How people and societies allocate scarce resources.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a031",
        "name": "Essays",
        "description": "Short reflections on ideas, culture, and experience.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a032",
        "name": "Fantasy",
        "description": "Speculative worlds built on magic and myth.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a033",
        "name": "Graphic Novels",
        "description": "Narrative told through sequential illustrations.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a034",
        "name": "History",
        "description": "Interpretations of events and people from the past.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a035",
        "name": "Human Computer Interaction",
        "description": "How people understand and use technology.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a036",
        "name": "Illustration",
        "description": "Images created to explain, decorate, or tell a story.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a037",
        "name": "Journalism",
        "description": "Reporting and analysis of current events.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a038",
        "name": "Linguistics",
        "description": "The scientific study of language and its structure.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a039",
        "name": "Literary Fiction",
        "description": "Character-driven fiction with an emphasis on craft.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a040",
        "name": "Mathematics",
        "description":
            "Patterns, quantities, and structures, proved rigorously.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a041",
        "name": "Memoir",
        "description": "Personal recollections of a life or a period of it.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a042",
        "name": "Music",
        "description":
            "Sounds, instruments, composition, and the culture around them.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a043",
        "name": "Nature Writing",
        "description": "Observations of the natural world and our place in it.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a044",
        "name": "Networks",
        "description": "How systems connect and exchange information.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a045",
        "name": "Philosophy",
        "description":
            "Fundamental questions about knowledge, being, and value.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a046",
        "name": "Photography",
        "description": "The art and technique of capturing images.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a047",
        "name": "Poetry",
        "description": "Concentrated language shaped by rhythm and image.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a048",
        "name": "Programming Languages",
        "description": "Tools and ideas for expressing computation.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a049",
        "name": "Psychology",
        "description": "The study of mind and behavior.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "name": "Science",
        "description":
            "Systematic knowledge of the physical and natural world.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a051",
        "name": "Science Fiction",
        "description":
            "Speculative fiction dealing with imaginative and futuristic concepts.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a052",
        "name": "Mystery",
        "description":
            "Fiction revolving around the solution of a crime or secrets.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a053",
        "name": "Technology",
        "description":
            "Non-fiction works discussing computing, artificial intelligence, and software.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a054",
        "name": "Short Stories",
        "description": "Compact fictional narratives with a single effect.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a055",
        "name": "Sociology",
        "description":
            "The study of society, institutions, and social relations.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a056",
        "name": "Space Exploration",
        "description": "The practice of exploring beyond Earth.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a057",
        "name": "Statistics",
        "description": "Collecting, analyzing, and interpreting data.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a058",
        "name": "Sustainability",
        "description": "Meeting present needs without compromising the future.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a059",
        "name": "Thriller",
        "description": "Fast-paced stories built around suspense and danger.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a060",
        "name": "Travel",
        "description": "Writing about places, journeys, and displacement.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a061",
        "name": "Urban Studies",
        "description": "How cities grow, function, and are experienced.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a062",
        "name": "Visual Culture",
        "description": "Meaning made through images and objects.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a063",
        "name": "Web Design",
        "description": "Designing sites and interfaces for the open web.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a064",
        "name": "Writing",
        "description": "Craft, process, and practice of composition.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a065",
        "name": "Young Adult",
        "description": "Stories written for teenage readers.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a066",
        "name": "Zoology",
        "description": "The scientific study of animals.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a067",
        "name": "Architecture",
        "description": "The design and construction of buildings and spaces.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a068",
        "name": "Astronomy",
        "description": "The study of celestial objects and the universe.",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a069",
        "name": "Botany",
        "description": "The scientific study of plants.",
      }),
    ];

    final users = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a030",
        "username": "coder_sam",
        "email": "samuel.dev@example.com",
        "profile": {
          "display_name": "Sam Thorne",
          "bio": "Building scalable systems and drinking espresso.",
          "location": "Seattle, WA",
        },
        "followers_count": 342,
        "created_at": "2023-01-15T08:30:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a031",
        "username": "design_maya",
        "email": "maya.art@example.com",
        "profile": {
          "display_name": "Maya Lin",
          "bio": "UI/UX enthusiast and digital illustrator.",
          "location": "Toronto, Canada",
        },
        "followers_count": 1280,
        "created_at": "2023-03-22T14:15:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a032",
        "username": "orbit_anna",
        "email": "orbit_anna@example.com",
        "profile": {
          "display_name": "Anna Okafor",
          "bio": "Collecting maps and marginalia.",
          "location": "Lisbon, Portugal",
        },
        "followers_count": 25,
        "created_at": "2023-01-01T00:00:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a033",
        "username": "quiet_kai",
        "email": "quiet_kai@example.com",
        "profile": {
          "display_name": "Kai Nakamura",
          "bio": "Building small tools for big ideas.",
          "location": "Kyoto, Japan",
        },
        "followers_count": 162,
        "created_at": "2023-01-04T01:07:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a034",
        "username": "map_maker",
        "email": "map_maker@example.com",
        "profile": {
          "display_name": "Rowan Hale",
          "bio": "Weekend hiker, weekday debugger.",
          "location": "Portland, OR",
        },
        "followers_count": 299,
        "created_at": "2023-01-07T02:14:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a035",
        "username": "pixel_petra",
        "email": "pixel_petra@example.com",
        "profile": {
          "display_name": "Petra Novak",
          "bio": "Illustrating things that hum.",
          "location": "Berlin, Germany",
        },
        "followers_count": 436,
        "created_at": "2023-01-10T03:21:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a036",
        "username": "byte_bruno",
        "email": "byte_bruno@example.com",
        "profile": {
          "display_name": "Bruno Alves",
          "bio": "Reading about oceans and writing about code.",
          "location": "Sao Paulo, Brazil",
        },
        "followers_count": 573,
        "created_at": "2023-01-13T04:28:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a037",
        "username": "trail_tessa",
        "email": "trail_tessa@example.com",
        "profile": {
          "display_name": "Tessa Lund",
          "bio": "Designer of quiet interfaces.",
          "location": "Oslo, Norway",
        },
        "followers_count": 710,
        "created_at": "2023-01-16T05:35:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a038",
        "username": "coffee_cleo",
        "email": "coffee_cleo@example.com",
        "profile": {
          "display_name": "Cleo Martin",
          "bio": "Always looking for a better question.",
          "location": "Montreal, Canada",
        },
        "followers_count": 847,
        "created_at": "2023-01-19T06:42:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a039",
        "username": "grid_gordon",
        "email": "grid_gordon@example.com",
        "profile": {
          "display_name": "Gordon Pike",
          "bio": "Gardener of tiny databases.",
          "location": "Bristol, UK",
        },
        "followers_count": 984,
        "created_at": "2023-01-22T07:49:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a040",
        "username": "nova_nina",
        "email": "nova_nina@example.com",
        "profile": {
          "display_name": "Nina Farouk",
          "bio": "Chasing efficient algorithms and slow mornings.",
          "location": "Cairo, Egypt",
        },
        "followers_count": 1121,
        "created_at": "2023-01-25T08:56:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a041",
        "username": "delta_dean",
        "email": "delta_dean@example.com",
        "profile": {
          "display_name": "Dean Whitmore",
          "bio": "Documenting the edges of systems.",
          "location": "Melbourne, Australia",
        },
        "followers_count": 1258,
        "created_at": "2023-01-28T09:03:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a042",
        "username": "sketch_sasha",
        "email": "sketch_sasha@example.com",
        "profile": {
          "display_name": "Sasha Ito",
          "bio": "Photographer of overlooked places.",
          "location": "Seoul, South Korea",
        },
        "followers_count": 1395,
        "created_at": "2023-01-31T10:10:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a043",
        "username": "loop_luca",
        "email": "loop_luca@example.com",
        "profile": {
          "display_name": "Luca Bianchi",
          "bio": "Making software for field researchers.",
          "location": "Nairobi, Kenya",
        },
        "followers_count": 1532,
        "created_at": "2023-02-03T11:17:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a044",
        "username": "river_ren",
        "email": "river_ren@example.com",
        "profile": {
          "display_name": "Ren Takahashi",
          "bio": "Interested in language and memory.",
          "location": "Amsterdam, Netherlands",
        },
        "followers_count": 1669,
        "created_at": "2023-02-06T12:24:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a045",
        "username": "pixel_ivy",
        "email": "pixel_ivy@example.com",
        "profile": {
          "display_name": "Ivy Olsen",
          "bio": "Keeper of an extensive bookmark list.",
          "location": "Austin, TX",
        },
        "followers_count": 1806,
        "created_at": "2023-02-09T13:31:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a046",
        "username": "signal_sam",
        "email": "signal_sam@example.com",
        "profile": {
          "display_name": "Sam Delacroix",
          "bio": "Testing assumptions one query at a time.",
          "location": "Warsaw, Poland",
        },
        "followers_count": 1943,
        "created_at": "2023-02-12T14:38:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a047",
        "username": "ember_eli",
        "email": "ember_eli@example.com",
        "profile": {
          "display_name": "Eli Moreau",
          "bio": "Drawing diagrams on napkins.",
          "location": "Vancouver, Canada",
        },
        "followers_count": 2080,
        "created_at": "2023-02-15T15:45:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a048",
        "username": "cloud_cam",
        "email": "cloud_cam@example.com",
        "profile": {
          "display_name": "Cameron Reid",
          "bio": "Curious about networks and neighborhoods.",
          "location": "Milan, Italy",
        },
        "followers_count": 2217,
        "created_at": "2023-02-18T16:52:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a049",
        "username": "atlas_arial",
        "email": "atlas_arial@example.com",
        "profile": {
          "display_name": "Arial Woods",
          "bio": "Writing about the built environment.",
          "location": "Dublin, Ireland",
        },
        "followers_count": 2354,
        "created_at": "2023-02-21T17:59:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "username": "mosaic_mo",
        "email": "mosaic_mo@example.com",
        "profile": {
          "display_name": "Mo Haddad",
          "bio": "Occasional poet, frequent reviewer.",
          "location": "Auckland, New Zealand",
        },
        "followers_count": 2491,
        "created_at": "2023-02-24T18:06:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a051",
        "username": "harbor_henry",
        "email": "harbor_henry@example.com",
        "profile": {
          "display_name": "Henry Vale",
          "bio": "Researching how people learn systems.",
          "location": "Stockholm, Sweden",
        },
        "followers_count": 2628,
        "created_at": "2023-02-27T19:13:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a052",
        "username": "lunar_lena",
        "email": "lunar_lena@example.com",
        "profile": {
          "display_name": "Lena Kovacs",
          "bio": "Collecting maps and marginalia.",
          "location": "Lisbon, Portugal",
        },
        "followers_count": 2765,
        "created_at": "2023-03-02T20:20:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a053",
        "username": "vector_vic",
        "email": "vector_vic@example.com",
        "profile": {
          "display_name": "Victor Sousa",
          "bio": "Building small tools for big ideas.",
          "location": "Kyoto, Japan",
        },
        "followers_count": 2902,
        "created_at": "2023-03-05T21:27:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a054",
        "username": "paper_paul",
        "email": "paper_paul@example.com",
        "profile": {
          "display_name": "Paul Emmerson",
          "bio": "Weekend hiker, weekday debugger.",
          "location": "Portland, OR",
        },
        "followers_count": 3039,
        "created_at": "2023-03-08T22:34:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a055",
        "username": "forest_fay",
        "email": "forest_fay@example.com",
        "profile": {
          "display_name": "Faye Adeyemi",
          "bio": "Illustrating things that hum.",
          "location": "Berlin, Germany",
        },
        "followers_count": 3176,
        "created_at": "2023-03-11T23:41:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a056",
        "username": "circuit_cora",
        "email": "circuit_cora@example.com",
        "profile": {
          "display_name": "Cora Lin",
          "bio": "Reading about oceans and writing about code.",
          "location": "Sao Paulo, Brazil",
        },
        "followers_count": 3313,
        "created_at": "2023-03-14T00:48:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a057",
        "username": "storm_stella",
        "email": "storm_stella@example.com",
        "profile": {
          "display_name": "Stella Jones",
          "bio": "Designer of quiet interfaces.",
          "location": "Oslo, Norway",
        },
        "followers_count": 3450,
        "created_at": "2023-03-17T01:55:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a058",
        "username": "meadow_milo",
        "email": "meadow_milo@example.com",
        "profile": {
          "display_name": "Milo Bertrand",
          "bio": "Always looking for a better question.",
          "location": "Montreal, Canada",
        },
        "followers_count": 3587,
        "created_at": "2023-03-20T02:02:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a059",
        "username": "syntax_sue",
        "email": "syntax_sue@example.com",
        "profile": {
          "display_name": "Sue Park",
          "bio": "Gardener of tiny databases.",
          "location": "Bristol, UK",
        },
        "followers_count": 3724,
        "created_at": "2023-03-23T03:09:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a060",
        "username": "canyon_carl",
        "email": "canyon_carl@example.com",
        "profile": {
          "display_name": "Carl Mendes",
          "bio": "Chasing efficient algorithms and slow mornings.",
          "location": "Cairo, Egypt",
        },
        "followers_count": 3861,
        "created_at": "2023-03-26T04:16:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a061",
        "username": "prism_pia",
        "email": "prism_pia@example.com",
        "profile": {
          "display_name": "Pia Rossi",
          "bio": "Documenting the edges of systems.",
          "location": "Melbourne, Australia",
        },
        "followers_count": 3998,
        "created_at": "2023-03-29T05:23:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a062",
        "username": "drift_dan",
        "email": "drift_dan@example.com",
        "profile": {
          "display_name": "Dan Whitfield",
          "bio": "Photographer of overlooked places.",
          "location": "Seoul, South Korea",
        },
        "followers_count": 4135,
        "created_at": "2023-04-01T06:30:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a063",
        "username": "orbit_ollie",
        "email": "orbit_ollie@example.com",
        "profile": {
          "display_name": "Ollie Grant",
          "bio": "Making software for field researchers.",
          "location": "Nairobi, Kenya",
        },
        "followers_count": 4272,
        "created_at": "2023-04-04T07:37:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a064",
        "username": "fable_finn",
        "email": "fable_finn@example.com",
        "profile": {
          "display_name": "Finn Baker",
          "bio": "Interested in language and memory.",
          "location": "Amsterdam, Netherlands",
        },
        "followers_count": 4409,
        "created_at": "2023-04-07T08:44:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a065",
        "username": "glacier_gus",
        "email": "glacier_gus@example.com",
        "profile": {
          "display_name": "Gus Halvorsen",
          "bio": "Keeper of an extensive bookmark list.",
          "location": "Austin, TX",
        },
        "followers_count": 4546,
        "created_at": "2023-04-10T09:51:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a066",
        "username": "ripple_rhea",
        "email": "ripple_rhea@example.com",
        "profile": {
          "display_name": "Rhea Kapoor",
          "bio": "Testing assumptions one query at a time.",
          "location": "Warsaw, Poland",
        },
        "followers_count": 4683,
        "created_at": "2023-04-13T10:58:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a067",
        "username": "marble_matt",
        "email": "marble_matt@example.com",
        "profile": {
          "display_name": "Matt Silva",
          "bio": "Drawing diagrams on napkins.",
          "location": "Vancouver, Canada",
        },
        "followers_count": 4820,
        "created_at": "2023-04-16T11:05:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a068",
        "username": "beacon_bea",
        "email": "beacon_bea@example.com",
        "profile": {
          "display_name": "Bea Laurent",
          "bio": "Curious about networks and neighborhoods.",
          "location": "Milan, Italy",
        },
        "followers_count": 157,
        "created_at": "2023-04-19T12:12:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a069",
        "username": "jungle_jules",
        "email": "jungle_jules@example.com",
        "profile": {
          "display_name": "Jules Moreno",
          "bio": "Writing about the built environment.",
          "location": "Dublin, Ireland",
        },
        "followers_count": 294,
        "created_at": "2023-04-22T13:19:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a070",
        "username": "noise_noah",
        "email": "noise_noah@example.com",
        "profile": {
          "display_name": "Noah Fischer",
          "bio": "Occasional poet, frequent reviewer.",
          "location": "Auckland, New Zealand",
        },
        "followers_count": 431,
        "created_at": "2023-04-25T14:26:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a071",
        "username": "sable_sara",
        "email": "sable_sara@example.com",
        "profile": {
          "display_name": "Sara Iqbal",
          "bio": "Researching how people learn systems.",
          "location": "Stockholm, Sweden",
        },
        "followers_count": 568,
        "created_at": "2023-04-28T15:33:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a072",
        "username": "tidal_tom",
        "email": "tidal_tom@example.com",
        "profile": {
          "display_name": "Tom Ashby",
          "bio": "Collecting maps and marginalia.",
          "location": "Lisbon, Portugal",
        },
        "followers_count": 705,
        "created_at": "2023-05-01T16:40:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a073",
        "username": "copper_cody",
        "email": "copper_cody@example.com",
        "profile": {
          "display_name": "Cody Reyes",
          "bio": "Building small tools for big ideas.",
          "location": "Kyoto, Japan",
        },
        "followers_count": 842,
        "created_at": "2023-05-04T17:47:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a074",
        "username": "vinyl_vee",
        "email": "vinyl_vee@example.com",
        "profile": {
          "display_name": "Vee Martin",
          "bio": "Weekend hiker, weekday debugger.",
          "location": "Portland, OR",
        },
        "followers_count": 979,
        "created_at": "2023-05-07T18:54:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a075",
        "username": "lantern_liz",
        "email": "lantern_liz@example.com",
        "profile": {
          "display_name": "Liz Sorensen",
          "bio": "Illustrating things that hum.",
          "location": "Berlin, Germany",
        },
        "followers_count": 1116,
        "created_at": "2023-05-10T19:01:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a076",
        "username": "comet_craig",
        "email": "comet_craig@example.com",
        "profile": {
          "display_name": "Craig Osei",
          "bio": "Reading about oceans and writing about code.",
          "location": "Sao Paulo, Brazil",
        },
        "followers_count": 1253,
        "created_at": "2023-05-13T20:08:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a077",
        "username": "quartz_quinn",
        "email": "quartz_quinn@example.com",
        "profile": {
          "display_name": "Quinn Harper",
          "bio": "Designer of quiet interfaces.",
          "location": "Oslo, Norway",
        },
        "followers_count": 1390,
        "created_at": "2023-05-16T21:15:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a078",
        "username": "cedar_cyrus",
        "email": "cedar_cyrus@example.com",
        "profile": {
          "display_name": "Cyrus Bell",
          "bio": "Always looking for a better question.",
          "location": "Montreal, Canada",
        },
        "followers_count": 1527,
        "created_at": "2023-05-19T22:22:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a079",
        "username": "sonic_sky",
        "email": "sonic_sky@example.com",
        "profile": {
          "display_name": "Sky Andersen",
          "bio": "Gardener of tiny databases.",
          "location": "Bristol, UK",
        },
        "followers_count": 1664,
        "created_at": "2023-05-22T23:29:00.000Z",
      }),
    ];

    final posts = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a040",
        "author_id": "60c72b2f9b1d8b0015f8a030",
        "content":
            "Just deployed my first custom MongoDB aggregation pipeline! Loving the flexibility.",
        "tags": ["mongodb", "database", "backend"],
        "likes_count": 42,
        "created_at": "2023-10-01T10:00:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a041",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "content":
            "Minimalist design isn't about removing features—it's about removing friction.",
        "tags": ["design", "ux", "product"],
        "likes_count": 115,
        "created_at": "2023-10-02T16:45:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a042",
        "author_id": "60c72b2f9b1d8b0015f8a030",
        "content": "Indexes are just signposts for your queries.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 5,
        "created_at": "2023-03-02T20:20:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a043",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "content": "A good schema starts with the questions you will ask.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 34,
        "created_at": "2023-03-05T21:27:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a044",
        "author_id": "60c72b2f9b1d8b0015f8a032",
        "content":
            "Shipped a tiny feature today and it made the whole app calmer.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 63,
        "created_at": "2023-03-08T22:34:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a045",
        "author_id": "60c72b2f9b1d8b0015f8a033",
        "content":
            "Reading through an old aggregation pipeline and finding new tricks.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 92,
        "created_at": "2023-03-11T23:41:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a046",
        "author_id": "60c72b2f9b1d8b0015f8a034",
        "content":
            "Nested documents make more sense once you sketch them on paper.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 121,
        "created_at": "2023-03-14T00:48:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a047",
        "author_id": "60c72b2f9b1d8b0015f8a035",
        "content": "The best dashboard is the one you rarely need to open.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 150,
        "created_at": "2023-03-17T01:55:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a048",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "content": "Spent the afternoon renaming a variable. Worth it.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 179,
        "created_at": "2023-03-20T02:02:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a049",
        "author_id": "60c72b2f9b1d8b0015f8a037",
        "content": "Text search works beautifully when the data is clean.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 208,
        "created_at": "2023-03-23T03:09:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "author_id": "60c72b2f9b1d8b0015f8a038",
        "content": "Reminder: sort before you paginate.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 237,
        "created_at": "2023-03-26T04:16:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a051",
        "author_id": "60c72b2f9b1d8b0015f8a039",
        "content": "A small cache can hide a very large problem.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 266,
        "created_at": "2023-03-29T05:23:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a052",
        "author_id": "60c72b2f9b1d8b0015f8a040",
        "content": "Wrote a script to summarize a week of commits.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 295,
        "created_at": "2023-04-01T06:30:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a053",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "content": "Design review taught me more than another tutorial would.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 324,
        "created_at": "2023-04-04T07:37:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a054",
        "author_id": "60c72b2f9b1d8b0015f8a042",
        "content": "Documents are flexible, but consistency is still a gift.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 353,
        "created_at": "2023-04-07T08:44:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a055",
        "author_id": "60c72b2f9b1d8b0015f8a043",
        "content": "Nothing beats a fast local copy of the data.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 382,
        "created_at": "2023-04-10T09:51:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a056",
        "author_id": "60c72b2f9b1d8b0015f8a044",
        "content": "Today I learned how to read an explain plan properly.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 411,
        "created_at": "2023-04-13T10:58:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a057",
        "author_id": "60c72b2f9b1d8b0015f8a045",
        "content": "A clear field name is documentation that never goes stale.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 440,
        "created_at": "2023-04-16T11:05:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a058",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "content": "Trying to make the empty state feel welcoming.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 469,
        "created_at": "2023-04-19T12:12:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a059",
        "author_id": "60c72b2f9b1d8b0015f8a047",
        "content": "The aggregation framework rewards patience.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 18,
        "created_at": "2023-04-22T13:19:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a060",
        "author_id": "60c72b2f9b1d8b0015f8a048",
        "content": "Moved a slow query behind a background job.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 47,
        "created_at": "2023-04-25T14:26:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a061",
        "author_id": "60c72b2f9b1d8b0015f8a049",
        "content": "A tiny validation rule saved us from a messy import.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 76,
        "created_at": "2023-04-28T15:33:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a062",
        "author_id": "60c72b2f9b1d8b0015f8a050",
        "content": "Good logs tell a story without revealing secrets.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 105,
        "created_at": "2023-05-01T16:40:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a063",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "content": "Looking for a better way to visualize nested arrays.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 134,
        "created_at": "2023-05-04T17:47:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a064",
        "author_id": "60c72b2f9b1d8b0015f8a052",
        "content":
            "The schema analyser is surprisingly good at spotting drift.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 163,
        "created_at": "2023-05-07T18:54:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a065",
        "author_id": "60c72b2f9b1d8b0015f8a053",
        "content": "Prototyped a new navigation model over lunch.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 192,
        "created_at": "2023-05-10T19:01:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a066",
        "author_id": "60c72b2f9b1d8b0015f8a054",
        "content":
            "Reduced a payload by half just by removing duplicated fields.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 221,
        "created_at": "2023-05-13T20:08:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a067",
        "author_id": "60c72b2f9b1d8b0015f8a055",
        "content": "A collection named well needs fewer comments.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 250,
        "created_at": "2023-05-16T21:15:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a068",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "content": "Testing with realistic data changes every assumption.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 279,
        "created_at": "2023-05-19T22:22:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a069",
        "author_id": "60c72b2f9b1d8b0015f8a057",
        "content": "The terminal is faster when commands are memorable.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 308,
        "created_at": "2023-05-22T23:29:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a070",
        "author_id": "60c72b2f9b1d8b0015f8a058",
        "content": "Watching a query plan change after an index is satisfying.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 337,
        "created_at": "2023-05-25T00:36:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a071",
        "author_id": "60c72b2f9b1d8b0015f8a059",
        "content": "Kept the UI quiet and let the data speak.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 366,
        "created_at": "2023-05-28T01:43:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a072",
        "author_id": "60c72b2f9b1d8b0015f8a060",
        "content": "Refactoring a pipeline into three readable stages.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 395,
        "created_at": "2023-05-31T02:50:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a073",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "content": "Learned that a projection can fix more than speed.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 424,
        "created_at": "2023-06-03T03:57:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a074",
        "author_id": "60c72b2f9b1d8b0015f8a062",
        "content": "Our new import flow handles messy JSON much better.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 453,
        "created_at": "2023-06-06T04:04:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a075",
        "author_id": "60c72b2f9b1d8b0015f8a063",
        "content": "A good default filter saves a lot of clicks.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 482,
        "created_at": "2023-06-09T05:11:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a076",
        "author_id": "60c72b2f9b1d8b0015f8a064",
        "content":
            "Exploring how to make tabs feel persistent rather than modal.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 31,
        "created_at": "2023-06-12T06:18:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a077",
        "author_id": "60c72b2f9b1d8b0015f8a065",
        "content": "Small screens demand honest information density.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 60,
        "created_at": "2023-06-15T07:25:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a078",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "content": "Documented a tricky authSource edge case today.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 89,
        "created_at": "2023-06-18T08:32:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a079",
        "author_id": "60c72b2f9b1d8b0015f8a067",
        "content":
            "Rebuilt a view and the schema card immediately reflected it.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 118,
        "created_at": "2023-06-21T09:39:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a080",
        "author_id": "60c72b2f9b1d8b0015f8a068",
        "content": "A grep through the logs found the bug in minutes.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 147,
        "created_at": "2023-06-24T10:46:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a081",
        "author_id": "60c72b2f9b1d8b0015f8a069",
        "content": "Copying a document should preserve its ObjectIds.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 176,
        "created_at": "2023-06-27T11:53:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a082",
        "author_id": "60c72b2f9b1d8b0015f8a070",
        "content": "Adding structure to notes made the search results useful.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 205,
        "created_at": "2023-06-30T12:00:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a083",
        "author_id": "60c72b2f9b1d8b0015f8a071",
        "content": "The pager is much clearer with an explicit total.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 234,
        "created_at": "2023-07-03T13:07:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a084",
        "author_id": "60c72b2f9b1d8b0015f8a072",
        "content": "Sketched a new icon set for file formats.",
        "tags": ["database", "backend", "mongodb"],
        "likes_count": 263,
        "created_at": "2023-07-06T14:14:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a085",
        "author_id": "60c72b2f9b1d8b0015f8a073",
        "content": "Clean sample data makes a demo feel effortless.",
        "tags": ["design", "ux", "frontend"],
        "likes_count": 292,
        "created_at": "2023-07-09T15:21:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a086",
        "author_id": "60c72b2f9b1d8b0015f8a074",
        "content": "A shortcut I use every day deserves a better label.",
        "tags": ["data", "analysis", "schema"],
        "likes_count": 321,
        "created_at": "2023-07-12T16:28:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a087",
        "author_id": "60c72b2f9b1d8b0015f8a075",
        "content": "Reviewing permissions before shipping is always worth it.",
        "tags": ["tips", "workflow", "tools"],
        "likes_count": 350,
        "created_at": "2023-07-15T17:35:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a088",
        "author_id": "60c72b2f9b1d8b0015f8a076",
        "content": "Turned a long script into a single comprehensible stage.",
        "tags": ["mobile", "flutter", "ui"],
        "likes_count": 379,
        "created_at": "2023-07-18T18:42:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a089",
        "author_id": "60c72b2f9b1d8b0015f8a077",
        "content": "Finished a performance pass with no visual changes at all.",
        "tags": ["learning", "notes", "community"],
        "likes_count": 408,
        "created_at": "2023-07-21T19:49:00.000Z",
      }),
    ];

    final comments = [
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a050",
        "post_id": "60c72b2f9b1d8b0015f8a040",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text":
            "Congrats Sam! Aggregation pipelines are a game changer once you get indexing right.",
        "created_at": "2023-10-01T10:15:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a051",
        "post_id": "60c72b2f9b1d8b0015f8a041",
        "author_id": "60c72b2f9b1d8b0015f8a030",
        "text": "100% agree. Simple interfaces hide complex engineering.",
        "created_at": "2023-10-02T17:05:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a052",
        "post_id": "60c72b2f9b1d8b0015f8a040",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text": "This matches what I saw on the last import.",
        "created_at": "2023-05-01T16:40:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a053",
        "post_id": "60c72b2f9b1d8b0015f8a043",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "text": "The explain plan made the difference obvious.",
        "created_at": "2023-05-04T17:47:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a054",
        "post_id": "60c72b2f9b1d8b0015f8a046",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "text": "Nice - I had not thought about the projection.",
        "created_at": "2023-05-07T18:54:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a055",
        "post_id": "60c72b2f9b1d8b0015f8a049",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "text": "Would a compound index help here?",
        "created_at": "2023-05-10T19:01:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a056",
        "post_id": "60c72b2f9b1d8b0015f8a052",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "text": "Exactly the reminder I needed this morning.",
        "created_at": "2023-05-13T20:08:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a057",
        "post_id": "60c72b2f9b1d8b0015f8a055",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "text": "I tried this with a larger collection and it held up.",
        "created_at": "2023-05-16T21:15:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a058",
        "post_id": "60c72b2f9b1d8b0015f8a058",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "text": "The before and after screenshots are very clear.",
        "created_at": "2023-05-19T22:22:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a059",
        "post_id": "60c72b2f9b1d8b0015f8a061",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "text": "Adding a date filter made the result much easier to read.",
        "created_at": "2023-05-22T23:29:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a060",
        "post_id": "60c72b2f9b1d8b0015f8a064",
        "author_id": "60c72b2f9b1d8b0015f8a071",
        "text": "Good point about keeping the UI quiet.",
        "created_at": "2023-05-25T00:36:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a061",
        "post_id": "60c72b2f9b1d8b0015f8a067",
        "author_id": "60c72b2f9b1d8b0015f8a076",
        "text": "I ran into the same edge case last week.",
        "created_at": "2023-05-28T01:43:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a062",
        "post_id": "60c72b2f9b1d8b0015f8a070",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text": "That is a much simpler pipeline than mine.",
        "created_at": "2023-05-31T02:50:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a063",
        "post_id": "60c72b2f9b1d8b0015f8a073",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "text": "The smaller payload also helped on mobile.",
        "created_at": "2023-06-03T03:57:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a064",
        "post_id": "60c72b2f9b1d8b0015f8a076",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "text": "Thanks, the sample data made this click for me.",
        "created_at": "2023-06-06T04:04:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a065",
        "post_id": "60c72b2f9b1d8b0015f8a079",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "text": "I prefer the explicit total in the pager too.",
        "created_at": "2023-06-09T05:11:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a066",
        "post_id": "60c72b2f9b1d8b0015f8a082",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "text": "This is a great use of a view.",
        "created_at": "2023-06-12T06:18:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a067",
        "post_id": "60c72b2f9b1d8b0015f8a085",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "text": "The new icon reads much better at 15 px.",
        "created_at": "2023-06-15T07:25:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a068",
        "post_id": "60c72b2f9b1d8b0015f8a088",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "text": "I would keep the filter editable until Find is pressed.",
        "created_at": "2023-06-18T08:32:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a069",
        "post_id": "60c72b2f9b1d8b0015f8a041",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "text": "A clear error message beats a silent fallback.",
        "created_at": "2023-06-21T09:39:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a070",
        "post_id": "60c72b2f9b1d8b0015f8a044",
        "author_id": "60c72b2f9b1d8b0015f8a071",
        "text": "This fixed the issue on my Android device.",
        "created_at": "2023-06-24T10:46:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a071",
        "post_id": "60c72b2f9b1d8b0015f8a047",
        "author_id": "60c72b2f9b1d8b0015f8a076",
        "text": "The secure storage note is important.",
        "created_at": "2023-06-27T11:53:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a072",
        "post_id": "60c72b2f9b1d8b0015f8a050",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text": "Nice catch on the cache path.",
        "created_at": "2023-06-30T12:00:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a073",
        "post_id": "60c72b2f9b1d8b0015f8a053",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "text": "I had the same problem with a stale key file.",
        "created_at": "2023-07-03T13:07:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a074",
        "post_id": "60c72b2f9b1d8b0015f8a056",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "text": "The offline resolution check saved me a build cycle.",
        "created_at": "2023-07-06T14:14:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a075",
        "post_id": "60c72b2f9b1d8b0015f8a059",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "text": "Bookmarked this for the next schema review.",
        "created_at": "2023-07-09T15:21:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a076",
        "post_id": "60c72b2f9b1d8b0015f8a062",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "text": "This is why I keep a scratch collection.",
        "created_at": "2023-07-12T16:28:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a077",
        "post_id": "60c72b2f9b1d8b0015f8a065",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "text": "Works well with nested arrays too.",
        "created_at": "2023-07-15T17:35:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a078",
        "post_id": "60c72b2f9b1d8b0015f8a068",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "text": "The smaller dataset is easier to demo.",
        "created_at": "2023-07-18T18:42:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a079",
        "post_id": "60c72b2f9b1d8b0015f8a071",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "text": "A straightforward change that improves the flow.",
        "created_at": "2023-07-21T19:49:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a080",
        "post_id": "60c72b2f9b1d8b0015f8a074",
        "author_id": "60c72b2f9b1d8b0015f8a071",
        "text": "I like how the status banner explains the save location.",
        "created_at": "2023-07-24T20:56:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a081",
        "post_id": "60c72b2f9b1d8b0015f8a077",
        "author_id": "60c72b2f9b1d8b0015f8a076",
        "text": "The tab title stayed readable at 320 px.",
        "created_at": "2023-07-27T21:03:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a082",
        "post_id": "60c72b2f9b1d8b0015f8a080",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text": "Good call on raising the SDK floor.",
        "created_at": "2023-07-30T22:10:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a083",
        "post_id": "60c72b2f9b1d8b0015f8a083",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "text": "This should make the release notes easier to write.",
        "created_at": "2023-08-02T23:17:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a084",
        "post_id": "60c72b2f9b1d8b0015f8a086",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "text": "Verified on a phone with a slow connection.",
        "created_at": "2023-08-05T00:24:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a085",
        "post_id": "60c72b2f9b1d8b0015f8a089",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "text": "The index names match the queries we actually run.",
        "created_at": "2023-08-08T01:31:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a086",
        "post_id": "60c72b2f9b1d8b0015f8a042",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "text": "A tiny detail, but it makes the modal feel finished.",
        "created_at": "2023-08-11T02:38:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a087",
        "post_id": "60c72b2f9b1d8b0015f8a045",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "text": "I hit that exact duplicate key error yesterday.",
        "created_at": "2023-08-14T03:45:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a088",
        "post_id": "60c72b2f9b1d8b0015f8a048",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "text": "The sample profile list is much tidier now.",
        "created_at": "2023-08-17T04:52:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a089",
        "post_id": "60c72b2f9b1d8b0015f8a051",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "text": "This is a neat way to keep credentials scoped.",
        "created_at": "2023-08-20T05:59:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a090",
        "post_id": "60c72b2f9b1d8b0015f8a054",
        "author_id": "60c72b2f9b1d8b0015f8a071",
        "text": "The document tree is easier to scan with 50 records.",
        "created_at": "2023-08-23T06:06:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a091",
        "post_id": "60c72b2f9b1d8b0015f8a057",
        "author_id": "60c72b2f9b1d8b0015f8a076",
        "text": "A clear description beats a long tooltip.",
        "created_at": "2023-08-26T07:13:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a092",
        "post_id": "60c72b2f9b1d8b0015f8a060",
        "author_id": "60c72b2f9b1d8b0015f8a031",
        "text": "Reusing the same field names keeps the schema stable.",
        "created_at": "2023-08-29T08:20:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a093",
        "post_id": "60c72b2f9b1d8b0015f8a063",
        "author_id": "60c72b2f9b1d8b0015f8a036",
        "text": "The pager counts are now easy to verify.",
        "created_at": "2023-09-01T09:27:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a094",
        "post_id": "60c72b2f9b1d8b0015f8a066",
        "author_id": "60c72b2f9b1d8b0015f8a041",
        "text": "Nice - the CSV card finally looks like a table.",
        "created_at": "2023-09-04T10:34:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a095",
        "post_id": "60c72b2f9b1d8b0015f8a069",
        "author_id": "60c72b2f9b1d8b0015f8a046",
        "text": "This is the behaviour I expected from Find.",
        "created_at": "2023-09-07T11:41:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a096",
        "post_id": "60c72b2f9b1d8b0015f8a072",
        "author_id": "60c72b2f9b1d8b0015f8a051",
        "text": "I appreciate the careful error handling here.",
        "created_at": "2023-09-10T12:48:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a097",
        "post_id": "60c72b2f9b1d8b0015f8a075",
        "author_id": "60c72b2f9b1d8b0015f8a056",
        "text": "Testing with more data exposed the layout issue.",
        "created_at": "2023-09-13T13:55:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a098",
        "post_id": "60c72b2f9b1d8b0015f8a078",
        "author_id": "60c72b2f9b1d8b0015f8a061",
        "text": "The connection modal still fits on a small phone.",
        "created_at": "2023-09-16T14:02:00.000Z",
      }),
      MongoDocument.fromMap({
        "_id": "60c72b2f9b1d8b0015f8a099",
        "post_id": "60c72b2f9b1d8b0015f8a081",
        "author_id": "60c72b2f9b1d8b0015f8a066",
        "text": "Everything is green after the change.",
        "created_at": "2023-09-19T15:09:00.000Z",
      }),
    ];

    databases = [
      MongoDatabase(
        name: 'library',
        collections: {
          'books': MongoCollection(
            name: 'books',
            documents: _typedSeedDocs(books),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'isbn_1', keys: {'isbn': 1}, unique: true),
              MongoIndex(name: 'title_text', keys: {'title': 'text'}),
              MongoIndex(name: 'publisher_id_1', keys: {'publisher_id': 1}),
            ],
          ),
          'publishers': MongoCollection(
            name: 'publishers',
            documents: _typedSeedDocs(publishers),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'name_1', keys: {'name': 1}),
            ],
          ),
          'genres': MongoCollection(
            name: 'genres',
            documents: _typedSeedDocs(genres),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'name_1', keys: {'name': 1}),
            ],
          ),
        },
      ),
      MongoDatabase(
        name: 'social_networks',
        collections: {
          'users': MongoCollection(
            name: 'users',
            documents: _typedSeedDocs(users),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(
                name: 'username_1',
                keys: {'username': 1},
                unique: true,
              ),
              MongoIndex(name: 'email_1', keys: {'email': 1}, unique: true),
            ],
          ),
          'posts': MongoCollection(
            name: 'posts',
            documents: _typedSeedDocs(posts),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'author_id_1', keys: {'author_id': 1}),
              MongoIndex(name: 'tags_1', keys: {'tags': 1}),
            ],
          ),
          'comments': MongoCollection(
            name: 'comments',
            documents: _typedSeedDocs(comments),
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}, unique: true),
              MongoIndex(name: 'post_id_1', keys: {'post_id': 1}),
              MongoIndex(name: 'author_id_1', keys: {'author_id': 1}),
            ],
          ),
        },
      ),
    ];
  }

  List<MongoDatabase> getDatabases() => databases;

  MongoDatabase? getDatabase(String name) {
    try {
      return databases.firstWhere((d) => d.name == name);
    } catch (_) {
      return null;
    }
  }

  MongoCollection? getCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    return db?.collections[collName];
  }

  /// Executes a `find` against the mock engine, mirroring
  /// `mongoEngine.findDocuments`: filter -> sort -> skip/limit -> project.
  /// Returns the paginated page of documents along with the total match count.
  QueryResult findDocuments(
    String dbName,
    String collName,
    QueryFilterOptions options,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) {
      return QueryResult(
        documents: const [],
        totalCount: 0,
        executionTimeMs: 0,
      );
    }

    Map parsedFilter = {};
    Map parsedProject = {};
    Map parsedSort = {};

    // Invalid partial JSON (e.g. the user is mid-typing "{") must never throw
    // out of a build. Mirror React's App-level catch: yield an empty result.
    try {
      if (options.filter.trim().isNotEmpty) {
        final parsed = tolerantParse(options.filter);
        if (parsed is Map) {
          parsedFilter = _normalizeExtendedJson(parsed) as Map;
        }
      }
      if (options.project.trim().isNotEmpty) {
        final parsed = tolerantParse(options.project);
        if (parsed is Map) {
          parsedProject = _normalizeExtendedJson(parsed) as Map;
        }
      }
      if (options.sort.trim().isNotEmpty) {
        final parsed = tolerantParse(options.sort);
        if (parsed is Map) {
          parsedSort = _normalizeExtendedJson(parsed) as Map;
        }
      }
    } catch (_) {
      return QueryResult(
        documents: const [],
        totalCount: 0,
        executionTimeMs: 0,
      );
    }

    // 1. Filter
    var filtered = coll.documents
        .where((d) => _matchesFilter(d.data, parsedFilter))
        .toList();
    final totalCount = filtered.length;

    // 2. Sort
    if (parsedSort.isNotEmpty) {
      filtered = _sortDocs(filtered, parsedSort);
    }

    // 3. Skip & Limit
    final skip = options.skip < 0 ? 0 : options.skip;
    final limit = options.limit < 1 ? 1 : options.limit;
    final paginated = filtered.skip(skip).take(limit).toList();

    // 4. Project
    final projected = parsedProject.isNotEmpty
        ? paginated
              .map(
                (d) =>
                    MongoDocument.fromMap(_applyProjection(d, parsedProject)),
              )
              .toList()
        : paginated;

    return QueryResult(
      documents: projected,
      totalCount: totalCount,
      executionTimeMs: 0.8,
    );
  }

  /// Distinct values of [field] across the documents matching [filter].
  ///
  /// Used by the shell's `db.<coll>.distinct(...)`. It reads the in-memory
  /// mirror, so it works for both the local engine and a connected server.
  List<dynamic> distinct(
    String dbName,
    String collName,
    String field,
    Map filter,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return [];
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final values = <dynamic>[];
    final seen = <String>{};
    for (final doc in coll.documents) {
      if (!_matchesFilter(doc.data, normalizedFilter)) continue;
      final value = _resolvePath(doc.data, field);
      if (value == null) continue;
      if (seen.add(jsonEncode(value))) values.add(value);
    }
    return values;
  }

  /// Computes per-field schema statistics for [collName] by scanning the
  /// in-memory documents (a generic stand-in for Compass's schema analysis,
  /// which works for any of the bundled collections).
  List<SchemaFieldStat> analyzeSchema(String dbName, String collName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.documents.isEmpty) return [];

    final docs = coll.documents;
    final total = docs.length;

    // Preserve first-seen field order across all documents.
    final fieldOrder = <String>[];
    for (final d in docs) {
      for (final key in d.data.keys) {
        if (!fieldOrder.contains(key)) fieldOrder.add(key);
      }
    }

    final result = <SchemaFieldStat>[];
    for (final field in fieldOrder) {
      final present = docs
          .map((d) => d.data[field])
          .where((v) => v != null)
          .toList();
      final missing = total - present.length;

      final typeCounts = <String, int>{};
      for (final v in present) {
        final type = field == '_id' ? 'ObjectId' : _jsonTypeOf(v);
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      final types = typeCounts.entries
          .map(
            (e) => SchemaFieldTypeStat(
              type: e.key,
              count: e.value,
              percentage: (e.value * 100) ~/ total,
            ),
          )
          .toList();

      num? min;
      num? max;
      for (final v in present) {
        if (v is num) {
          if (min == null || v < min) min = v;
          if (max == null || v > max) max = v;
        }
      }

      result.add(
        SchemaFieldStat(
          name: field,
          path: field,
          types: types,
          totalValues: present.length,
          missingCount: missing,
          missingPercentage: (missing * 100) ~/ total,
          distinctCount: present.map((v) => jsonEncode(v)).toSet().length,
          sampleValues: present.take(3).toList(),
          min: min,
          max: max,
        ),
      );
    }
    return result;
  }

  /// Maps a decoded JSON value to the BSON type name Compass would display.
  String _jsonTypeOf(dynamic v) {
    if (v is MongoObjectId) return 'ObjectId';
    if (v is String) return 'String';
    if (v is int) return 'Int32';
    if (v is double) return 'Double';
    if (v is bool) return 'Boolean';
    if (v is List) return 'Array';
    if (v is Map) return 'Object';
    return 'Null';
  }

  // ---------------------------------------------------------------------------
  // Mutations (ported from src/services/mongoEngine.ts)
  // ---------------------------------------------------------------------------

  void resetToDefaults() {
    seedSampleData();
  }

  String generateObjectId() {
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000)
        .toRadixString(16);
    final random = List.generate(
      16,
      (_) => _random.nextInt(16).toRadixString(16),
    ).join();
    return (timestamp + random).substring(0, 24);
  }

  bool createDatabase(String dbName, [String initialCollName = 'users']) {
    if (getDatabase(dbName) != null) return false;
    databases.add(
      MongoDatabase(
        name: dbName,
        collections: {
          initialCollName: MongoCollection(
            name: initialCollName,
            documents: [
              MongoDocument.fromMap({
                '_id': MongoObjectId(generateObjectId()),
                'createdAt': DateTime.now().toIso8601String(),
                'name': 'Sample Item',
                'active': true,
              }),
            ],
            indexes: [
              MongoIndex(name: '_id_', keys: {'_id': 1}),
            ],
          ),
        },
      ),
    );
    return true;
  }

  bool dropDatabase(String dbName) {
    final before = databases.length;
    databases.removeWhere((d) => d.name == dbName);
    return databases.length < before;
  }

  bool createCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    if (db == null || db.collections.containsKey(collName)) return false;
    db.collections[collName] = MongoCollection(
      name: collName,
      documents: [],
      indexes: [
        MongoIndex(name: '_id_', keys: {'_id': 1}),
      ],
    );
    return true;
  }

  bool createView(
    String dbName,
    String viewName,
    String sourceCollName,
    List<dynamic> pipeline,
  ) {
    final db = getDatabase(dbName);
    if (db == null) throw Exception('Database "$dbName" not found');
    final clean = viewName.trim();
    if (clean.isEmpty) throw Exception('View name cannot be empty');
    if (clean.contains('\$') || clean.startsWith('.')) {
      throw Exception(
        'Invalid view name: cannot contain "\$" or begin with "."',
      );
    }
    if (db.collections.containsKey(clean)) {
      throw Exception(
        'A collection or view named "$clean" already exists in database "$dbName"',
      );
    }
    final source = db.collections[sourceCollName];
    if (source == null) {
      throw Exception(
        'Source collection "$sourceCollName" does not exist in database "$dbName"',
      );
    }

    final normalizedPipeline = _normalizeExtendedJson(pipeline) as List;
    final docs = _runPipeline(source.documents, normalizedPipeline, dbName);
    db.collections[clean] = MongoCollection(
      name: clean,
      documents: docs,
      indexes: [
        MongoIndex(name: '_id_', keys: {'_id': 1}, sizeKb: 0),
      ],
      isView: true,
      viewOn: sourceCollName,
      pipeline: normalizedPipeline,
    );
    return true;
  }

  /// Replaces the definition (source collection + pipeline) of an existing view.
  ///
  /// Kept separate from [createView] so [RealMongoService] can sequence the
  /// server-side drop + recreate in one operation instead of firing a second
  /// create through the [createView] override.
  bool updateView(
    String dbName,
    String viewName,
    String sourceCollName,
    List<dynamic> pipeline,
  ) {
    final db = getDatabase(dbName);
    if (db == null) throw Exception('Database "$dbName" not found');
    final existing = db.collections[viewName];
    if (existing == null || !existing.isView) {
      throw Exception('"$viewName" is not a view in database "$dbName"');
    }
    final source = db.collections[sourceCollName];
    if (source == null) {
      throw Exception(
        'Source collection "$sourceCollName" does not exist in database "$dbName"',
      );
    }

    final normalizedPipeline = _normalizeExtendedJson(pipeline) as List;
    final docs = _runPipeline(source.documents, normalizedPipeline, dbName);
    db.collections[viewName] = MongoCollection(
      name: viewName,
      documents: docs,
      indexes: [
        MongoIndex(name: '_id_', keys: {'_id': 1}, sizeKb: 0),
      ],
      isView: true,
      viewOn: sourceCollName,
      pipeline: normalizedPipeline,
    );
    return true;
  }

  bool dropCollection(String dbName, String collName) {
    final db = getDatabase(dbName);
    if (db == null || !db.collections.containsKey(collName)) return false;
    db.collections.remove(collName);
    return true;
  }

  bool renameDatabase(String oldName, String newName) {
    final clean = newName.trim();
    if (clean.isEmpty) throw Exception('Database name cannot be empty');
    if (clean == oldName) return true;
    final db = getDatabase(oldName);
    if (db == null) throw Exception('Database "$oldName" not found');
    if (RegExp(r'[/\\. "\$*<>:|?]').hasMatch(clean)) {
      throw Exception(
        'Database name cannot contain spaces or any of: / \\ . " \$ * < > : | ?',
      );
    }
    if (clean.length > 63) {
      throw Exception('Database name must be fewer than 64 characters');
    }
    if (getDatabase(clean) != null) {
      throw Exception('Database "$clean" already exists');
    }

    final idx = databases.indexWhere((d) => d.name == oldName);
    databases[idx] = MongoDatabase(name: clean, collections: db.collections);
    return true;
  }

  bool renameCollection(String dbName, String oldName, String newName) {
    final db = getDatabase(dbName);
    if (db == null) throw Exception('Database "$dbName" not found');
    final clean = newName.trim();
    if (clean.isEmpty) throw Exception('Collection name cannot be empty');
    if (clean == oldName) return true;
    final coll = db.collections[oldName];
    if (coll == null) {
      throw Exception(
        'Collection or view "$oldName" not found in database "$dbName"',
      );
    }
    if (clean.contains('\$')) {
      throw Exception('Collection names cannot contain the "\$" character');
    }
    if (clean.startsWith('system.')) {
      throw Exception(
        'Collection names cannot start with the "system." prefix',
      );
    }
    if (db.collections.containsKey(clean)) {
      throw Exception(
        'A collection or view named "$clean" already exists in database "$dbName"',
      );
    }

    final renamed = <String, MongoCollection>{};
    db.collections.forEach((key, val) {
      if (key == oldName) {
        renamed[clean] = MongoCollection(
          name: clean,
          documents: val.documents,
          indexes: val.indexes,
          validator: val.validator,
          validationLevel: val.validationLevel,
          validationAction: val.validationAction,
          isView: val.isView,
          viewOn: val.viewOn,
          pipeline: val.pipeline,
        );
      } else {
        if (val.isView && val.viewOn == oldName) {
          val.viewOn = clean;
        }
        renamed[key] = val;
      }
    });
    db.collections
      ..clear()
      ..addAll(renamed);
    return true;
  }

  MongoDocument insertDocument(
    String dbName,
    String collName,
    Map<String, dynamic> doc,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) throw Exception('Collection not found');
    if (coll.isView) {
      throw Exception(
        'Cannot insert document: "$collName" is a read-only MongoDB view.',
      );
    }

    final newMap = <String, dynamic>{
      for (final entry in doc.entries)
        entry.key: _normalizeExtendedJson(entry.value),
    };
    // A user-supplied `_id` (string or ObjectId) is kept as typed; only a
    // missing `_id` gets a generated BSON ObjectId.
    newMap['_id'] = newMap['_id'] ?? MongoObjectId(generateObjectId());

    for (final index in coll.indexes) {
      if (index.unique) {
        for (final existing in coll.documents) {
          final conflict = index.keys.keys.every((key) {
            final v1 = _resolvePath(existing.data, key);
            final v2 = _resolvePath(newMap, key);
            return v1 != null &&
                v2 != null &&
                _sameValue(v1, v2, looseId: key == '_id');
          });
          if (conflict) {
            throw Exception(
              'E11000 duplicate key error collection: $dbName.$collName index: ${index.name}',
            );
          }
        }
      }
    }

    final newDoc = MongoDocument.fromMap(newMap);
    coll.documents.insert(0, newDoc);
    return newDoc;
  }

  bool updateDocument(
    String dbName,
    String collName,
    String docId,
    Map<String, dynamic> updatedFields,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.isView) {
      throw Exception(
        'Cannot update document: "$collName" is a read-only MongoDB view.',
      );
    }
    final index = coll.documents.indexWhere((d) => d.id == docId);
    if (index == -1) return false;

    coll.documents[index] = MongoDocument.fromMap(
      _applyUpdate(
        coll.documents[index].data,
        updatedFields,
        fallbackId: docId,
      ),
    );
    return true;
  }

  /// Applies a MongoDB update document to [data] and returns the new map.
  ///
  /// Operator maps (`$set` / `$unset` / `$inc` / `$push` / `$pull`) merge into
  /// a copy; a plain map is a full replacement (MongoDB semantics) that keeps
  /// `_id`. Shared by [updateDocument] and [updateMany] so both understand the
  /// same operators.
  Map<String, dynamic> _applyUpdate(
    Map<String, dynamic> data,
    Map update, {
    required String fallbackId,
  }) {
    final normalized = _normalizeExtendedJson(update) as Map;
    final hasOperator = normalized.keys.any(
      (key) => key.toString().startsWith(r'$'),
    );

    if (!hasOperator) {
      return <String, dynamic>{
        for (final entry in normalized.entries)
          entry.key.toString(): entry.value,
        '_id': data['_id'] ?? fallbackId,
      };
    }

    final map = Map<String, dynamic>.from(data);

    final set = normalized[r'$set'];
    if (set is Map) {
      set.forEach((key, value) => _setPath(map, key.toString(), value));
    }

    final unset = normalized[r'$unset'];
    if (unset is Map) {
      for (final key in unset.keys) {
        _unsetPath(map, key.toString());
      }
    }

    final inc = normalized[r'$inc'];
    if (inc is Map) {
      inc.forEach((key, value) {
        _setPath(
          map,
          key.toString(),
          _asNum(_resolvePath(map, key.toString())) + _asNum(value),
        );
      });
    }

    final push = normalized[r'$push'];
    if (push is Map) {
      push.forEach((key, value) {
        final current = _resolvePath(map, key.toString());
        final list = current is List
            ? List<dynamic>.from(current)
            : <dynamic>[];
        if (value is Map && value.containsKey(r'$each')) {
          final each = value[r'$each'];
          if (each is List) list.addAll(each);
        } else {
          list.add(value);
        }
        _setPath(map, key.toString(), list);
      });
    }

    final pull = normalized[r'$pull'];
    if (pull is Map) {
      pull.forEach((key, value) {
        final current = _resolvePath(map, key.toString());
        if (current is List) {
          _setPath(
            map,
            key.toString(),
            current.where((item) => item != value).toList(),
          );
        }
      });
    }

    return map;
  }

  bool deleteDocument(String dbName, String collName, String docId) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.isView) {
      throw Exception(
        'Cannot delete document: "$collName" is a read-only MongoDB view.',
      );
    }
    final before = coll.documents.length;
    coll.documents.removeWhere((d) => d.id == docId);
    return coll.documents.length < before;
  }

  int deleteMany(String dbName, String collName, Map filter) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return 0;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final before = coll.documents.length;
    coll.documents.removeWhere((d) => _matchesFilter(d.data, normalizedFilter));
    return before - coll.documents.length;
  }

  bool deleteOne(String dbName, String collName, Map filter) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return false;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    final index = coll.documents.indexWhere(
      (d) => _matchesFilter(d.data, normalizedFilter),
    );
    if (index == -1) return false;
    coll.documents.removeAt(index);
    return true;
  }

  int updateMany(String dbName, String collName, Map filter, Map update) {
    final coll = getCollection(dbName, collName);
    if (coll == null || coll.isView) return 0;
    final normalizedFilter = _normalizeExtendedJson(filter) as Map;
    var count = 0;
    for (var i = 0; i < coll.documents.length; i++) {
      final d = coll.documents[i];
      if (!_matchesFilter(d.data, normalizedFilter)) continue;
      coll.documents[i] = MongoDocument.fromMap(
        _applyUpdate(d.data, update, fallbackId: d.id),
      );
      count++;
    }
    return count;
  }

  bool createIndex(String dbName, String collName, MongoIndex index) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    if (coll.indexes.any((i) => i.name == index.name)) return false;
    coll.indexes.add(
      MongoIndex(
        name: index.name,
        keys: index.keys,
        unique: index.unique,
        sparse: index.sparse,
        sizeKb: _random.nextInt(40) + 16,
      ),
    );
    return true;
  }

  bool dropIndex(String dbName, String collName, String indexName) {
    final coll = getCollection(dbName, collName);
    if (coll == null || indexName == '_id_') return false;
    final before = coll.indexes.length;
    coll.indexes.removeWhere((i) => i.name == indexName);
    return coll.indexes.length < before;
  }

  bool saveValidator(
    String dbName,
    String collName,
    Map<String, dynamic>? validator,
    String level,
    String action,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) return false;
    coll.validator = validator;
    coll.validationLevel = level;
    coll.validationAction = action;
    return true;
  }

  /// Tolerant JSON parser mirroring `mongoEngine.tolerantParse` (supports
  /// unquoted keys, single-quoted strings, and mongosh constructors such as
  /// `ObjectId("...")` / `ISODate("...")`).
  dynamic tolerantParse(String jsonStr) {
    if (jsonStr.trim().isEmpty) return {};
    final trimmed = jsonStr.trim();
    final preprocessed = preprocessMongoJson(trimmed);
    final cleaned = preprocessed
        .replaceAllMapped(
          RegExp(r'([{,]\s*)([a-zA-Z0-9_$.]+)\s*:'),
          (m) => '${m[1]}"${m[2]}":',
        )
        .replaceAll("'", '"');
    try {
      return jsonDecode(cleaned);
    } catch (_) {
      return jsonDecode(preprocessed);
    }
  }

  /// Converts Extended JSON wrappers (`{"$oid": ...}`, `{"$date": ...}`,
  /// `{"$timestamp": ...}`) into the values the in-memory mirror stores:
  /// ObjectIds keep their BSON type ([MongoObjectId]) and dates become ISO-8601
  /// strings. [RealMongoService] applies the same shape to server documents and
  /// reverses it when writing back.
  dynamic _normalizeExtendedJson(dynamic value) {
    if (value is Map) {
      if (value.length == 1) {
        if (value.containsKey(r'$oid')) {
          final oid = value[r'$oid'];
          if (oid is String) return MongoObjectId(oid);
        }
        if (value.containsKey(r'$date')) {
          final date = value[r'$date'];
          if (date is String) return date;
          if (date is int) {
            return DateTime.fromMillisecondsSinceEpoch(date).toIso8601String();
          }
        }
        if (value.containsKey(r'$timestamp')) {
          final ts = value[r'$timestamp'];
          if (ts is Map && ts['t'] is int) {
            return DateTime.fromMillisecondsSinceEpoch(
              (ts['t'] as int) * 1000,
            ).toIso8601String();
          }
        }
      }
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key.toString(): _normalizeExtendedJson(entry.value),
      };
    }
    if (value is List) {
      return value.map(_normalizeExtendedJson).toList();
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Aggregation pipeline execution (used by views and aggregations view)
  // ---------------------------------------------------------------------------

  QueryResult runAggregation(
    String dbName,
    String collName,
    List<dynamic> pipeline,
  ) {
    final coll = getCollection(dbName, collName);
    if (coll == null) {
      return QueryResult(
        documents: const [],
        totalCount: 0,
        executionTimeMs: 0.0,
      );
    }
    final stopwatch = Stopwatch()..start();
    try {
      final normalizedPipeline = _normalizeExtendedJson(pipeline) as List;
      final results = _runPipeline(coll.documents, normalizedPipeline, dbName);
      stopwatch.stop();
      return QueryResult(
        documents: results,
        totalCount: results.length,
        executionTimeMs: (stopwatch.elapsedMicroseconds / 1000.0).clamp(
          0.2,
          9999.0,
        ),
      );
    } catch (_) {
      stopwatch.stop();
      rethrow;
    }
  }

  List<dynamic> parseAggregationScript(String script) {
    if (script.trim().isEmpty) return [];
    var cleaned = script.trim();
    final match = RegExp(
      r'\.aggregate\s*\(\s*(\[[\s\S]*\])\s*\);?\s*$',
    ).firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)!.trim();
    }
    final parsed = tolerantParse(cleaned);
    if (parsed is List) return parsed;
    if (parsed is Map) return [parsed];
    return [];
  }

  List<MongoDocument> _runPipeline(
    List<MongoDocument> docs,
    List<dynamic> pipeline,
    String dbName,
  ) {
    var current = docs
        .map(
          (d) =>
              MongoDocument(id: d.id, data: Map<String, dynamic>.from(d.data)),
        )
        .toList();

    for (final rawStage in pipeline) {
      if (rawStage is! Map || rawStage.isEmpty) continue;
      final keys = rawStage.keys.map((k) => k.toString()).toList();
      final op = keys.firstWhere(
        (k) => k.startsWith('\$'),
        orElse: () => keys.first,
      );
      current = _applyStage(
        current,
        op,
        rawStage[op] ?? rawStage[keys.first],
        dbName,
      );
    }
    return current;
  }

  List<MongoDocument> _applyStage(
    List<MongoDocument> docs,
    String operator,
    dynamic content,
    String dbName,
  ) {
    switch (operator) {
      case '\$lookup':
        if (content is Map) {
          final fromCollName = content['from']?.toString() ?? '';
          final localField = content['localField']?.toString() ?? '';
          final foreignField = content['foreignField']?.toString() ?? '';
          final asField = content['as']?.toString() ?? 'joined';
          final foreignColl = getCollection(dbName, fromCollName);
          final foreignDocs = foreignColl?.documents ?? [];

          return docs.map((d) {
            final localVal = _resolvePath(d.data, localField);
            final matches = foreignDocs
                .where((fd) => _resolvePath(fd.data, foreignField) == localVal)
                .map((fd) => Map<String, dynamic>.from(fd.data))
                .toList();
            final clone = Map<String, dynamic>.from(d.data);
            clone[asField] = matches;
            return MongoDocument.fromMap(clone);
          }).toList();
        }
        return docs;
      case '\$match':
        if (content is Map) {
          return docs.where((d) => _matchesFilter(d.data, content)).toList();
        }
        return docs;
      case '\$project':
        if (content is Map) {
          return docs
              .map((d) => MongoDocument.fromMap(_applyProjection(d, content)))
              .toList();
        }
        return docs;
      case '\$sort':
        if (content is Map) return _sortDocs(docs, content);
        return docs;
      case '\$limit':
        final n = _asNum(content).toInt();
        return docs.take(n < 0 ? 0 : n).toList();
      case '\$skip':
        final n = _asNum(content).toInt();
        return docs.skip(n < 0 ? 0 : n).toList();
      case '\$count':
        final field = content is String ? content : 'count';
        return [
          MongoDocument.fromMap({field: docs.length}),
        ];
      case '\$addFields':
        if (content is Map) {
          return docs.map((d) {
            final clone = Map<String, dynamic>.from(d.data);
            content.forEach((k, v) {
              clone[k.toString()] = (v is String && v.startsWith('\$'))
                  ? _resolvePath(d.data, v.substring(1))
                  : v;
            });
            return MongoDocument.fromMap(clone);
          }).toList();
        }
        return docs;
      case '\$unwind':
        final path =
            (content is String
                    ? content
                    : (content is Map ? content['path']?.toString() ?? '' : ''))
                .replaceFirst(RegExp(r'^\$'), '');
        final preserve =
            content is Map && content['preserveNullAndEmptyArrays'] == true;
        final unrolled = <MongoDocument>[];
        for (final doc in docs) {
          final arr = _resolvePath(doc.data, path);
          if (arr is List && arr.isNotEmpty) {
            for (final item in arr) {
              final clone = Map<String, dynamic>.from(doc.data);
              _setPath(clone, path, item);
              unrolled.add(MongoDocument.fromMap(clone));
            }
          } else if (preserve) {
            unrolled.add(doc);
          }
        }
        return unrolled;
      case '\$group':
        if (content is Map) return _applyGroup(docs, content);
        return docs;
      default:
        return docs;
    }
  }

  List<MongoDocument> _applyGroup(List<MongoDocument> docs, Map content) {
    final idExpr = content['_id'];
    final groups = <String, List<MongoDocument>>{};

    for (final doc in docs) {
      String key = 'null';
      if (idExpr is String && idExpr.startsWith('\$')) {
        key = '${_resolvePath(doc.data, idExpr.substring(1))}';
      } else if (idExpr == null) {
        key = 'null';
      } else if (idExpr is Map) {
        key = jsonEncode(idExpr);
      }
      groups.putIfAbsent(key, () => []).add(doc);
    }

    final result = <MongoDocument>[];
    groups.forEach((key, groupDocs) {
      final out = <String, dynamic>{};
      if (idExpr == null) {
        out['_id'] = null;
      } else if (idExpr is String && idExpr.startsWith('\$')) {
        out['_id'] = _resolvePath(groupDocs.first.data, idExpr.substring(1));
      } else {
        out['_id'] = key;
      }

      content.forEach((field, accExpr) {
        if (field == '_id' || accExpr is! Map || accExpr.isEmpty) return;
        final accOp = accExpr.keys.first.toString();
        final exprVal = accExpr[accOp];
        final path = (exprVal is String && exprVal.startsWith('\$'))
            ? exprVal.substring(1)
            : '';

        switch (accOp) {
          case '\$sum':
            if (exprVal is num) {
              out[field.toString()] = groupDocs.length * exprVal;
            } else if (path.isNotEmpty) {
              out[field.toString()] = groupDocs.fold<num>(
                0,
                (acc, d) => acc + _asNum(_resolvePath(d.data, path)),
              );
            }
            break;
          case '\$avg':
            if (path.isNotEmpty) {
              final total = groupDocs.fold<num>(
                0,
                (acc, d) => acc + _asNum(_resolvePath(d.data, path)),
              );
              out[field.toString()] = groupDocs.isEmpty
                  ? 0
                  : total / groupDocs.length;
            }
            break;
          case '\$min':
          case '\$max':
            final vals = groupDocs
                .map((d) => _resolvePath(d.data, path))
                .where((v) => v != null)
                .toList();
            if (vals.isNotEmpty) {
              vals.sort((a, b) => _compare(a, b) ?? 0);
              out[field.toString()] = accOp == '\$min' ? vals.first : vals.last;
            }
            break;
          case '\$push':
            out[field.toString()] = groupDocs
                .map((d) => _resolvePath(d.data, path))
                .toList();
            break;
          case '\$first':
            out[field.toString()] = groupDocs.isEmpty
                ? null
                : _resolvePath(groupDocs.first.data, path);
            break;
        }
      });

      result.add(MongoDocument.fromMap(out));
    });
    return result;
  }

  bool _matchesFilter(Map<String, dynamic> doc, Map filter) {
    if (filter.isEmpty) return true;

    for (final entry in filter.entries) {
      final key = entry.key.toString();
      final expected = entry.value;

      if (key == '\$and') {
        if (expected is List &&
            !expected.every((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }
      if (key == '\$or') {
        if (expected is List &&
            !expected.any((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }
      if (key == '\$nor') {
        if (expected is List &&
            expected.any((s) => s is Map && _matchesFilter(doc, s))) {
          return false;
        }
        continue;
      }

      final val = _resolvePath(doc, key);

      if (expected is Map) {
        for (final opEntry in expected.entries) {
          final op = opEntry.key.toString();
          final opVal = opEntry.value;
          switch (op) {
            case '\$eq':
              if (!_sameValue(val, opVal, looseId: key == '_id')) return false;
              break;
            case '\$ne':
              if (_sameValue(val, opVal, looseId: key == '_id')) return false;
              break;
            case '\$gt':
              final c = _compare(val, opVal);
              if (c == null || c <= 0) return false;
              break;
            case '\$gte':
              final c = _compare(val, opVal);
              if (c == null || c < 0) return false;
              break;
            case '\$lt':
              final c = _compare(val, opVal);
              if (c == null || c >= 0) return false;
              break;
            case '\$lte':
              final c = _compare(val, opVal);
              if (c == null || c > 0) return false;
              break;
            case '\$in':
              if (opVal is List) {
                if (val is List) {
                  if (!val.any(
                    (item) => _anySameValue(opVal, item, looseId: key == '_id'),
                  )) {
                    return false;
                  }
                } else if (!_anySameValue(opVal, val, looseId: key == '_id')) {
                  return false;
                }
              }
              break;
            case '\$nin':
              if (opVal is List) {
                if (val is List) {
                  if (val.any(
                    (item) => _anySameValue(opVal, item, looseId: key == '_id'),
                  )) {
                    return false;
                  }
                } else if (_anySameValue(opVal, val, looseId: key == '_id')) {
                  return false;
                }
              }
              break;
            case '\$exists':
              final exists = val != null;
              if (exists != (opVal == true)) return false;
              break;
            case '\$regex':
              final options = expected['\$options']?.toString() ?? 'i';
              final regex = RegExp(
                opVal.toString(),
                caseSensitive: options != 'i',
              );
              if (!regex.hasMatch('${val ?? ''}')) return false;
              break;
            case '\$size':
              if (val is! List || val.length != _asNum(opVal).toInt()) {
                return false;
              }
              break;
          }
        }
      } else {
        if (val is List) {
          if (!val.any(
            (item) => _sameValue(item, expected, looseId: key == '_id'),
          )) {
            return false;
          }
        } else if (!_sameValue(val, expected, looseId: key == '_id')) {
          return false;
        }
      }
    }
    return true;
  }

  Map<String, dynamic> _applyProjection(MongoDocument doc, Map proj) {
    final isExclusive = proj.values.any((v) => v == 0);
    final result = isExclusive
        ? Map<String, dynamic>.from(doc.data)
        : <String, dynamic>{};

    if (proj['_id'] == 0) {
      result.remove('_id');
    } else if (doc.data['_id'] != null) {
      result['_id'] = doc.data['_id'];
    }

    if (isExclusive) {
      proj.forEach((k, v) {
        if (v == 0) result.remove(k.toString());
      });
    } else {
      proj.forEach((k, v) {
        if (v == 1 && k.toString() != '_id') {
          result[k.toString()] = _resolvePath(doc.data, k.toString());
        }
      });
    }
    return result;
  }

  List<MongoDocument> _sortDocs(List<MongoDocument> docs, Map sortSpec) {
    final keys = sortSpec.keys.map((k) => k.toString()).toList();
    final sorted = List<MongoDocument>.from(docs);
    sorted.sort((a, b) {
      for (final key in keys) {
        final order = _asNum(sortSpec[key]);
        final valA = _resolvePath(a.data, key);
        final valB = _resolvePath(b.data, key);
        if (valA == valB) continue;
        if (valA == null) return 1;
        if (valB == null) return -1;
        final c = _compare(valA, valB) ?? 0;
        if (c != 0) return order < 0 ? -c : c;
      }
      return 0;
    });
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Internal utilities
  // ---------------------------------------------------------------------------

  num _asNum(dynamic value) {
    if (value is num) return value;
    if (value is bool) return value ? 1 : 0;
    return num.tryParse('$value') ?? 0;
  }

  int? _compare(dynamic a, dynamic b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    if (a is Comparable) {
      try {
        return a.compareTo(b);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Equality used by the filter matcher.
  ///
  /// For `_id`, a hex string and an [MongoObjectId] with the same value compare
  /// equal, so the app's string-based id lookups keep working. For every other
  /// field the types must match, which is what keeps a string field distinct
  /// from an ObjectId field.
  bool _sameValue(dynamic a, dynamic b, {required bool looseId}) {
    if (a == b) return true;
    if (looseId) {
      final sa = a?.toString();
      final sb = b?.toString();
      if (sa != null && sb != null && sa == sb) return true;
    }
    return false;
  }

  bool _anySameValue(List candidates, dynamic value, {required bool looseId}) =>
      candidates.any(
        (candidate) => _sameValue(candidate, value, looseId: looseId),
      );

  dynamic _resolvePath(dynamic obj, String path) {
    if (obj == null || path.isEmpty) return null;
    dynamic cur = obj;
    for (final part in path.split('.')) {
      if (cur == null) return null;
      if (cur is Map) {
        cur = cur[part];
      } else if (cur is List) {
        final i = int.tryParse(part);
        cur = (i != null && i >= 0 && i < cur.length) ? cur[i] : null;
      } else {
        return null;
      }
    }
    return cur;
  }

  void _setPath(Map<String, dynamic> obj, String path, dynamic val) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (var i = 0; i < parts.length - 1; i++) {
      final p = parts[i];
      if (cur[p] is! Map) cur[p] = <String, dynamic>{};
      cur = cur[p];
    }
    cur[parts.last] = val;
  }

  void _unsetPath(Map<String, dynamic> obj, String path) {
    final parts = path.split('.');
    dynamic cur = obj;
    for (var i = 0; i < parts.length - 1; i++) {
      if (cur[parts[i]] is! Map) return;
      cur = cur[parts[i]];
    }
    cur.remove(parts.last);
  }
}

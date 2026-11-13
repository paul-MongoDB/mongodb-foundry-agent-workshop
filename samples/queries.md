# Prompts and Atlas verification

These examples demonstrate direct queries, aggregation, and semantic retrieval. Run them against `sample_mflix.embedded_movies` using the [short instructions](../docs/agent-instructions.md). Inspect the trace for the exact response under review.

## 1. Exact count

```text
How many movies were released in 1994?
```

Pass: a successful MCP `count` or `aggregate` call with `year: 1994`, and the answer agrees with its tool result and an independent Atlas query. A valid `find` followed by counting only a limited result set is not sufficient for an exact total.

In Atlas Data Explorer, open the collection's **Aggregations** tab:

```json
[
  { "$match": { "year": 1994 } },
  { "$count": "movieCount" }
]
```

The development dataset returned **66**. Use the collection's current answer. Match any additional filters used by the agent before comparing counts.

## 2. Genre statistics

```text
Across all documents in this collection, what are the five most common genres, and how many documents belong to each? Count each document once in each genre it belongs to.
```

Pass: a successful MCP aggregation expands genres, counts memberships, sorts, and returns five groups. Match the filter scope when comparing results. A movie can count in several genres, once in each.

### Verify genre counts in Atlas

The example counts all documents in the assigned collection. This independent pipeline deduplicates genre values within each document before counting:

```json
[
  {
    "$project": {
      "genres": { "$setUnion": [{ "$ifNull": ["$genres", []] }, []] }
    }
  },
  { "$unwind": "$genres" },
  { "$group": { "_id": "$genres", "movieCount": { "$sum": 1 } } },
  { "$sort": { "movieCount": -1, "_id": 1 } },
  { "$limit": 5 }
]
```

For an optional movies-only comparison, add `{ "$match": { "type": "movie" } }` as the first stage. This changes the scope and the totals; do not use that variant for the all-document example.

Observed all-document results, verified through Foundry MCP and an independent Atlas pipeline in the new Azure Free cluster:

| Genre | Count |
|---|---:|
| Action | 2,381 |
| Drama | 1,271 |
| Fantasy | 1,055 |
| Adventure | 923 |
| Comedy | 887 |

These are reference observations, not fixed answers for every copy of the sample data.

## 3. Semantic retrieval

```text
Find five movies about a group of astronauts struggling to survive a dangerous mission in space.
```

Pass: a successful MCP aggregation on the intended collection starts with `$vectorSearch`, uses `vector_index_fullplot` on `fullplot` with natural-language `query.text`, and returns supporting documents. No separate embedding tool is required for this auto-embedding index. Review plots for relevance; do not require a fixed title list.

For an independent mechanism check in Atlas, use:

```json
[
  {
    "$vectorSearch": {
      "index": "vector_index_fullplot",
      "path": "fullplot",
      "query": { "text": "a group of astronauts struggling to survive a dangerous mission in space" },
      "numCandidates": 200,
      "limit": 5
    }
  },
  {
    "$project": {
      "_id": 0,
      "title": 1,
      "year": 1,
      "fullplot": 1,
      "score": { "$meta": "vectorSearchScore" }
    }
  }
]
```

For a direct result comparison, copy the agent's actual query text and pipeline parameters from its trace. Query expansion, filters, candidate count, and deduplication can change the returned titles. Similar titles alone do not establish that the agent executed vector search.

## Fresh-chat check

Start **New chat** with the same saved agent and repeat the semantic question. Confirm that connection, index discovery, and vector search succeed without earlier messages. This checks conversational independence; it does not replace testing OAuth consent with a fresh identity.

## Additional queries

A broader theme was exercised during development but gave mixed relevance in the Atlas Search Tester. Use it to discuss retrieval quality after the concrete core example:

```text
Find five movies about hope and redemption.
```

These are extension prompts rather than validated acceptance cases. Use tool results and inspect traces to assess them.

```text
Find five movies about finding belonging in an unfamiliar place.
```

```text
Find five movies about rebuilding a life after a setback.
```

```text
What highly rated movies are about time travel?
```

The last prompt combines thematic retrieval with a rating constraint. Inspect how the agent defines “highly rated,” applies filters, and limits its answer to retrieved candidates. Do not treat a ranking over a small candidate set as an exhaustive ranking of the entire catalog.

```text
Show me five movies starring Tom Hanks, including title and year.
```

```text
What is the average runtime of action movies?
```

## Failure handling

Use a fresh chat to try an unavailable database or collection. A passing response reports the actual tool failure or absence of data and does not invent movie facts. Perform read-only tests; do not disable authentication or attempt writes to induce a failure.

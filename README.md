# MongoDB Atlas + Microsoft Foundry

Build a movie assistant that answers questions from live MongoDB Atlas data. Connect a Microsoft Foundry agent to the Atlas-hosted remote MCP server and use Atlas Automated Embedding for semantic search.

**[Start with setup from scratch →](docs/setup-from-scratch.md)**

Already have your Atlas collection, automated embedding index, and Foundry model ready? Follow the [agent connection and usage guide](docs/usage.md).

## How it works

```text
Your question -> Microsoft Foundry agent -> Atlas-hosted remote MCP server
                                                    |
                                                    v
                                   sample_mflix.embedded_movies
                                   +-- Direct queries: retrieve and count
                                   +-- Aggregations: calculate statistics
                                   +-- Vector Search: find stories by meaning
                                       with Atlas Automated Embedding
```

Use Foundry and Atlas in the browser. MongoDB hosts the MCP server, and Atlas handles embedding generation. The remote path requires no local development environment, separate embedding API, or MCP container deployment.

## Prerequisites

- An Azure subscription and permissions to create a Foundry project and deploy a compatible chat model.
- An Atlas account, project, and eligible cluster with sample data and read-only remote MCP access.
- An active automated embedding index for semantic queries.
- Access to the connector's **Managed OAuth Identity Passthrough** flow.

The [setup guide](docs/setup-from-scratch.md) walks through preparation starting with an Azure subscription and no Atlas account.

**Availability:** the managed OAuth integration was tested in a Microsoft/MongoDB delegated authorization pilot. Confirm availability in your tenant, subscription, and region. See [troubleshooting](docs/troubleshooting.md).

## Documentation

| Task | Guide |
|---|---|
| Create accounts and prepare resources | [Setup from scratch](docs/setup-from-scratch.md) |
| Create the agent and connect remote MCP | [Connection and usage](docs/usage.md) |
| Copy the short prompt | [Agent instructions](docs/agent-instructions.md) |
| Try queries and independently verify results | [Query examples](samples/queries.md) |
| Diagnose connection, approval, or retrieval issues | [Troubleshooting](docs/troubleshooting.md) |
| Operate your own MCP server on Azure | [Optional self-managed MCP](docs/self-managed-mcp.md) |
| Review available screenshots | [Image inventory](docs/images/README.md) |

## Tested behavior

Hands-on checks used GPT-5 at **Low reasoning effort**, a direct Atlas remote MCP attachment, environment-specific instructions, and an Atlas `autoEmbed` index on `fullplot` using `voyage-4`.

- An exact count for `year: 1994` returned 66 and matched an independent Atlas query.
- Five genre aggregation totals matched an independent Atlas aggregation using the same document scope.
- A fresh-chat semantic query executed `$vectorSearch` with query text and returned supporting movie documents.

These are observations for the tested sample and configuration. Verify actual tool input/output and compare against your own collection; a plausible answer alone does not establish database retrieval.

## Documentation checks

```bash
python3 scripts/check-docs.py
```

An optional public-source snapshot can be generated with:

```bash
python3 scripts/package-source.py
```

The snapshot is written to `dist/atlas-foundry-source.zip`. It includes an integrity manifest and excludes local credentials, private working material, browser state, and Git history. Source files remain in this repository.

## References

- [Foundry MCP tools](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/tools/model-context-protocol)
- [Foundry MCP authentication](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/mcp-authentication)
- [Atlas-hosted MCP server](https://www.mongodb.com/docs/mcp-server/overview/)
- [MongoDB Automated Embedding](https://www.mongodb.com/docs/vector-search/crud-embeddings/automated-embedding/)

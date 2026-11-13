# Troubleshooting the remote MCP integration

Start with **Traces beneath the response you are investigating**. An earlier consent attempt and a later successful answer can have different traces. Read the failed tool's input and error before changing permissions or instructions.

## The MongoDB catalog item or Managed OAuth option is missing

This integration depends on the MongoDB Atlas MCP Server catalog integration and its Managed OAuth flow. Confirm the delegated authorization pilot is available in the intended environment. Confirm this before configuring your agent. Do not replace Atlas authentication with **Unauthenticated**; that setting belongs only to the separately deployed sample server in the optional guide.

## Sign-in succeeds but consent repeats

Consent can be requested at first tool use rather than when the tool is attached. A green sign-in message establishes completion of that consent step, not a successful database query.

Complete the first flow and return to Foundry. If a second request appears, complete it once. If another follows, inspect the latest error rather than continuing a login loop. Record the response ID, tool error, tool attachment type, and consent sequence for the pilot support team. Review requested scopes before consenting and keep tokens out of issue reports.

A fresh Atlas account was subsequently authorized successfully from Foundry in the same Incognito session, and its later fresh-chat query required no new consent. Repeated consent was observed earlier during development. The cause has not been established. A later fresh-chat run with the existing authorized direct connection needed no further consent; this does not establish every account configuration or multi-user pilot behavior.

## The agent asks for a project or cluster

Check the saved [short instructions](agent-instructions.md). All three Atlas values must be populated and refer to the intended environment. Project listing may be paginated: receiving 50 projects does not mean the account has exactly 50.

A remote MCP connection gives access to tools. A database connection tool still needs a project ID and cluster name. Supplying these defaults avoids a long project/cluster selection exchange.

## The agent says it lacks data access

Inspect the tool output. The model's explanation alone does not prove an Atlas permissions problem.

- If no connection attempt exists, check the saved defaults and tool attachment first.
- If `remote-atlas-connect` returns an access error, confirm the signed-in identity, project ID, cluster name, and assigned data access with your Atlas administrator.
- If project listing works but data calls fail, verify read-only data access in addition to project visibility.
- If the connection handle is invalid or expired, look for a new `remote-atlas-connect` call and retry with its returned handle.

The agent recovered automatically from an invalid connection handle in one validated run. Granting broader roles should follow a real authorization error and your organization's access policy.

## A toolbox attachment fails but the direct tool works

The tested configuration uses a direct attachment because that configuration was demonstrated working. Development changed both the approval configuration and attachment type, so the cause remains unresolved.

For a controlled investigation separately, compare the same tool connection, model, prompt, and approval policy in fresh chats. Inspect the actual toolbox version attached to the agent and whether configuration changes reached that version. Then compare against a newly attached direct tool. Do not conclude that all toolboxes fail from this single observation.

Approval changes may apply only to the specific tool instance and agent, as the configuration dialog indicates. Verify the saved instance you are actually invoking.

## The new agent has a toolbox and Web search already attached

Foundry created a default toolbox containing Web search during the new-agent rehearsal. Open the toolbox's **Actions → Opt out**, confirm, then remove the remaining Web search tool separately. Opting out retains the tools; it does not turn them off. Add the Atlas Remote MCP tool directly afterward.

The opt-out dialog also says toolbox skills, tool search, and versioned reusable tool sets will be unavailable. None were needed for the tested direct-attachment path. This is a documented choice for this example, not evidence that toolboxes cannot work.

## A response appears without any database operation

With **Never auto-approve tools**, the first post-consent response in the new-account rehearsal listed familiar movies after tool discovery, with no query execution span. A subsequent explicit count request did call `remote-atlas-connect` and `count`, and required a separate approval for each. Both returned successfully after **Approve once**.

For the prepared read-only configuration, set the agent's MCP instance to **Always auto-approve all tools**, select **Apply**, then **Save**. Verify the saved value. Changing OAuth consent does not change tool approval. A fresh semantic run after that saved setting executed connection, index discovery, and `$vectorSearch` without approval prompts.

If you keep manual approval, approve each requested read operation and inspect its actual output. Do not call a plausible title list a passed query test.

## Atlas usage reports zero immediately after embedding

The new index was Ready before the usage dashboards reflected consumption. After refresh, the build-only free-token counter reported 371,802, later 371,830 after validation searches. Check **AUTO EMBEDDING → Usage → Free Usage**, the actual model, and the reporting period. Read the exact consumed-token text rather than the rounded available balance. No fixed reporting delay was measured.

## Token rate limit exceeded

Open **Manage → Quota → Token per minute** and inspect the actual model deployment. Distinguish its allocation from the subscription's shared allocation. TPM measures allowed throughput, rather than a purchased balance or live billed consumption.

Allow quota changes to propagate and respect retry delays. Avoid repeated immediate retries. A short question can still have a large context because of tool definitions, history, and tool results; inspect usage rather than inferring it from visible text.

Size quota for your measured workload. The development suggestion of 250K TPM for one tester is not a universal requirement. Measure complete turns, including tool context, and monitor actual Azure billing separately from quota.

## An answer appears despite a tool discovery error

Find the trace for that exact answer. A `tools/list` or `mcp_list_tools` failure indicates a tool-discovery problem; it is not a database result. A familiar title or plausible count is insufficient evidence of successful retrieval.

Keep the model and instructions fixed while resolving the connection. Re-run the exact-count check and verify both successful tool output and an independent Atlas query.

## The answer looks semantic but the trace shows keyword search

The semantic checkpoint requires a successful `$vectorSearch` using query text on the prepared automated embedding index. Regex matching on `plot` or a `$search` keyword query does not satisfy it.

First check the index discovery result: `vector_index_fullplot` should be active, of type `autoEmbed`, on `fullplot`. Existing OpenAI or Voyage vector fields are a different path. If the data is prepared but the agent chose the wrong path, use this diagnostic prompt:

```text
Inspect the collection's search indexes. Use its existing automated embedding index to find five movies about astronauts surviving a dangerous space mission, then explain any tool error you encounter.
```

This is a troubleshooting hint, not part of the baseline agent instructions. If it is repeatedly required, record the failure and revisit the model/prompt before relying on the configuration.

## Numerical results differ from the examples

Use the actual prepared dataset as the source of truth. The development count of 66 and genre results in the [query examples](../samples/queries.md) are observations, not universal answers for every copy of `sample_mflix`.

Match all filters. In development, the genre aggregation included `type: "movie"`; counting every document produced different totals. A document can belong to several genres. Compare the same collection, dataset version, and filter scope before diagnosing a counting error.

## Semantic titles vary

Inspect the query text, index, returned plots, filters, and any deduplication. Models may expand the user's concept differently, and search rankings can vary. Evaluate the retrieval mechanism and supporting evidence rather than a fixed list of titles. Two validated runs used different query expansions and returned different recommendations.

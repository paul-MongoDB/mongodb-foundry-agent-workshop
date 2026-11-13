# Screenshot inventory

These are actual UI captures from the November 9, 2026 rehearsal and user-supplied account-setup screenshots, cropped to the relevant application content. Email destinations in two account images are covered with opaque redaction blocks. Browser tabs, address bars, account photos, personal organization names, and personal Azure resource-name headers are excluded. Images have not been reconstructed to imply an unobserved setup state.

| Image | What it demonstrates |
|---|---|
| [atlas-signup-methods.png](atlas-signup-methods.png) | Account creation methods; the populated personal form is excluded |
| [atlas-verify-email.png](atlas-verify-email.png) | Email verification and Continue; address redacted |
| [atlas-mfa-methods.png](atlas-mfa-methods.png) | MFA enrollment choices observed after verification |
| [atlas-mfa-email.png](atlas-mfa-email.png) | Email MFA example with recipient redacted and code fields empty |
| [count-atlas.png](count-atlas.png) | Independent new-cluster Atlas count of 66 |
| [genre-atlas.png](genre-atlas.png) | Independent all-document genre counts in the new cluster |
| [genre-trace.png](genre-trace.png) | Actual Foundry MCP grouping pipeline for genre statistics |
| [cluster-azure.png](cluster-azure.png) | Created generic sandbox cluster, explicitly Free on Azure |
| [sample-data.png](sample-data.png) | Loaded embedded_movies collection with 3,483 documents and precomputed embedding fields |
| [atlas-readonly.png](atlas-readonly.png) | Organization AI client access enabled with read-only selected |
| [autoembed-ready.png](autoembed-ready.png) | Ready / Queryable index on `embedded_movies.fullplot` using `voyage-4` |
| [embedding-usage.png](embedding-usage.png) | Later Voyage-4 usage of 371,830 tokens after the build and validation queries |
| [mcp-approval.png](mcp-approval.png) | Saved direct MCP tool instance with Always auto-approve all tools |
| [foundry-result.png](foundry-result.png) | New agent version 3, direct MCP attachment, and the successful space-survival answer |
| [vector-trace.png](vector-trace.png) | Successful connection, index discovery, and the actual `$vectorSearch` pipeline |

The trace contains example conversation/span/connection handles, not credentials. Users must inspect their own trace; these handles are not reusable setup values. The usage image is deliberately labeled as a later reading: the initial build-only counter was 371,802 tokens.

## Coverage and optional additions

The supplied signup screenshots close the account-creation illustration gap without registering another identity. The first screenshot was cropped to its sign-in methods, excluding the populated name, address, and password fields. Of the two duplicate verification screens, the later image with Continue enabled was used. Address bars and browser tabs were removed from every supplied image, so verification links and authentication parameters are not distributed.

The documented route is usable with the current fifteen images. Additional illustrations could show initial Free/Azure selection before creation, Foundry resource-group creation, toolbox opt-out, remote catalog selection, and consent. These are optional visual improvements; the steps and final-state evidence are already documented. Do not create an account, grant access, or provision a resource solely to obtain another screenshot.

The two email redactions are intentional privacy edits, not altered UI settings. The original user screenshots remain untouched outside the repository. Only the cropped, sanitized outputs are included in the review archive.

## Refresh rules

Use `atlas-sandbox-free`, `atlas-movie-agent`, and `atlas-remote-mcp` for examples. Capture key decisions and evidence rather than every click. Crop away personal names, email addresses, avatars, browser chrome, subscription details, and secrets. Preserve the setting labels and enough application context to orient a reader. Check each final crop visually and update its caption if the measured counter or UI changes.

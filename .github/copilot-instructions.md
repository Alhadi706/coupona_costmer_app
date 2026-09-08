## graphify

For any question about this repo's architecture, structure, components, or how to add/modify/find
code, your first action should be `graphify query "<question>"` when `graphify-out/graph.json`
exists. Use `graphify path "<A>" "<B>"` for relationship questions and `graphify explain "<concept>"`
for focused-concept questions. These return a scoped subgraph, usually much smaller than the full
report or raw grep output.

Triggers: "how do I…", "where is…", "what does … do", "add/modify a <component>",
"explain the architecture", or anything that depends on how files or classes relate.

If `graphify-out/wiki/index.md` exists, use it for broad navigation. Read `graphify-out/GRAPH_REPORT.md`
only for broad architecture review or when query/path/explain do not surface enough context. Only read
source files when (a) modifying/debugging specific code, (b) the graph lacks the needed detail, or
(c) the graph is missing or stale.

Type `/graphify` in Copilot Chat to build or update the graph.

## Separation of Concerns and File Size

- Organize code by responsibility: each file should represent one clear role, such as a state owner, a service domain, a type/model group, helper logic, or a focused UI component set.
- Treat 300-400 lines as a review signal, not a strict limit. When a file grows beyond this range, inspect it for a coherent responsibility that can move to a separate file.
- Extract logically cohesive helper functions, types, services, dialogs, or sub-components. Do not split code only to reduce the line count.
- Preserve public APIs and behavior during extraction. Keep stateful logic with its owning state object, and pass data and callbacks explicitly to extracted widgets.
- Avoid creating generic dumping-ground helpers. A new file must have a clear responsibility, a meaningful name, and a focused dependency surface.
- After each extraction, run a targeted analyzer or test for the affected slice before continuing.

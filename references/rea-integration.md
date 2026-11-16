# REA (Reverse Engineer Anything) MCP Integration in Autonomous Loop

This guide documents how autonomous agents use **REA** MCP tools to inspect binaries, decompile code, trace execution, and drive autonomous reconstruction and verification workflows without human intervention.

---

## 1. Overview

REA provides 200+ specialized reverse engineering and artifact inspection tools through its Model Context Protocol (MCP) server named `rea`. 

When an autonomous loop goal involves:
- Reverse-engineering closed-source binaries, libraries, or packages
- Reconstructing source code from shipped targets (ELF, PE, Mach-O, APK, ASAR, WASM, JVM, .NET)
- Understanding proprietary protocols, binary schemas, or SQLite databases
- Comparing binary or bundle versions and detecting behavior changes
- Verifying behavioral fidelity between original binaries and reconstructed source

The agent is authorized to call REA MCP tools and consume their results directly within the loop.

---

## 2. Calling REA MCP Tools

REA tools are invoked through the standard MCP interface:
- **Server Name**: `rea`
- **Tool Name**: The specific REA tool (e.g., `binary_overview`, `analyze_function`, `procedure_pseudo_code`)
- **Arguments**: JSON object matching the tool's schema

### Example MCP Tool Calls:

```json
// Inspect binary architecture and metadata
call_mcp_tool(
  ServerName: "rea",
  ToolName: "binary_overview",
  Arguments: { "path": "/path/to/target_binary" }
)

// Decompile a specific function to pseudo-code
call_mcp_tool(
  ServerName: "rea",
  ToolName: "procedure_pseudo_code",
  Arguments: { "address": "0x00401230" }
)

// Analyze an Electron ASAR or extracted JavaScript bundle
call_mcp_tool(
  ServerName: "rea",
  ToolName: "analyze_javascript_application",
  Arguments: { "path": "/path/to/app.asar" }
)

// Compare original binary against reconstructed implementation
call_mcp_tool(
  ServerName: "rea",
  ToolName: "compare_artifacts",
  Arguments: { 
    "baseline_path": "/path/to/original",
    "target_path": "/path/to/reconstructed"
  }
)
```

---

## 3. Tool Routing by Target Type

| Target Type | Primary REA Tools |
|---|---|
| **Native Binaries (ELF, Mach-O, PE)** | `open_binary`, `binary_overview`, `analyze_function`, `procedure_pseudo_code`, `procedure_assembly`, `get_call_graph`, `xrefs`, `close_binary` |
| **Electron / JavaScript / ASAR** | `analyze_javascript_application`, `analyze_web_bundle`, `recover_javascript_sources`, `compare_javascript_export_shapes` |
| **Android (APK / DEX)** | `inspect_android_package`, `search_android_classes`, `inspect_android_class`, `inspect_android_method`, `decode_android_resources` |
| **Managed Assemblies (.NET / Java)** | `inspect_managed_artifact`, `inspect_managed_members`, `verify_managed_native_boundaries` |
| **Data & Databases** | `inspect_sqlite_database`, `inspect_packet_capture`, `decode_signal_recording` |
| **Dynamic & Debugging** | `start_rizin_debug_session`, `instrument_with_frida`, `trace_call_path`, `close_rizin_debug_session`, `close_frida_session` |
| **Reconstruction & Fidelity** | `build_reconstruction_obligation_ledger`, `compare_functions`, `verify_reconstruction`, `correlate_static_and_runtime` |

---

## 4. Ingesting Tool Call Results in the Loop Lifecycle

REA tool calling seamlessly feeds each phase of the autonomous loop:

### Phase 0: Intake
1. Call `binary_overview` or `inspect_artifact` on the target artifact.
2. In `GOAL.md`, list exact acceptance criteria derived from the binary: exported symbol counts, protocol specifications, API surface, or reconstruction coverage thresholds.
3. Record binary hashes, architectures, and preliminary findings in `LOG.md`.

### Execution Cycle:
1. **ORIENT**: Review the current unknown obligation ledger (`build_reconstruction_obligation_ledger`) or remaining un-reconstructed functions.
2. **CHOOSE**: Select the next function, module, or schema to reverse engineer.
3. **PLAN**: Log the target address or symbol and the planned REA tool sequence in `LOG.md`.
4. **INSPECT & EXTRACT**:
   - Call `procedure_pseudo_code`, `analyze_function`, or `get_call_graph`.
   - Parse the decompiled logic, type structures, and branching conditions.
   - Log architectural decisions and deductions in `DECISIONS.md`.
5. **TEST (Red)**: Write unit tests expressing the exact inputs, outputs, and edge cases discovered in the decompiled code.
6. **BUILD (Green)**: Write clean, idiomatic source code in the target project that implements the logic revealed by REA.
7. **VERIFY**:
   - Run the test suite (`scripts/verify.sh --quick`).
   - Call `verify_reconstruction` or `compare_functions` to validate that the reconstructed code satisfies behavioral invariants.
8. **PASS**: Commit the reconstructed module and updated tests.

### Finishing:
1. Verify 100% of acceptance criteria in `GOAL.md`.
2. Produce a final reconstruction report in `.loop/FINAL_REPORT.md` including symbol coverage and evidence hashes.
3. Ensure all REA sessions are closed.

---

## 5. Session & Resource Hygiene

- **Always Close Sessions**: Whenever an interactive or stateful REA tool session is opened (`open_binary`, `start_rizin_debug_session`, `start_frida_session`), call the corresponding close tool (`close_binary`, `close_rizin_debug_session`, `close_frida_session`) as soon as analysis is complete.
- **Log Compactly**: Do not dump megabytes of raw disassembly into `LOG.md`. Extract and record high-level signatures, key algorithms, and logic summaries.
- **Stay Read-Only on Targets**: Target binaries and reference artifacts must be treated as immutable read-only evidence. Never modify the target binary itself.

import Foundation

enum CrossServerTools {
    static let listServersToolName = "list_servers"
    static let listSessionsToolName = "list_sessions"
    static let runOnServerToolName = "run_on_server"

    static func buildDynamicToolSpecs() -> [DynamicToolSpec] {
        [
            listServersSpec(),
            listSessionsSpec()
        ]
    }

    private static func listServersSpec() -> DynamicToolSpec {
        DynamicToolSpec(
            name: listServersToolName,
            description: "List connected servers, including local and remote hosts.",
            inputSchema: AnyEncodable(JSONSchema.object([:], required: []))
        )
    }

    private static func listSessionsSpec() -> DynamicToolSpec {
        DynamicToolSpec(
            name: listSessionsToolName,
            description: "List recent sessions across all connected servers or on a specific server.",
            inputSchema: AnyEncodable(JSONSchema.object([
                "server": .string(description: "Optional server name or ID to filter by."),
                "server_id": .string(description: "Optional server ID to filter by."),
                "limit": .number(description: "Optional maximum number of sessions per server.")
            ], required: []))
        )
    }

    private static func runOnServerSpec() -> DynamicToolSpec {
        DynamicToolSpec(
            name: runOnServerToolName,
            description: "Run a prompt on a specific connected server and return the result.",
            inputSchema: AnyEncodable(JSONSchema.object([
                "server": .string(description: "Target server name or ID."),
                "server_id": .string(description: "Target server ID."),
                "prompt": .string(description: "Prompt to send."),
                "thread_id": .string(description: "Optional existing thread ID to reuse."),
                "model": .string(description: "Optional model override."),
                "effort": .string(description: "Optional reasoning effort override."),
                "service_tier": .string(description: "Optional service tier override.")
            ], required: ["prompt"]))
        )
    }
}

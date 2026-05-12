declare module "@opencode-ai/plugin" {
  interface PluginContext {
    tool: string;
    args: Record<string, unknown>;
    result: string;
    suggest?: (message: string) => void;
    [key: string]: unknown;
  }

  interface PluginHooks {
    "session.created"?: (ctx: PluginContext) => Promise<void | unknown>;
    "tool.execute.before"?: (ctx: PluginContext) => Promise<void | unknown>;
    "tool.execute.after"?: (ctx: PluginContext) => Promise<void | unknown>;
  }

  interface PluginDefinition {
    name: string;
    hooks: PluginHooks;
  }

  export function definePlugin(definition: PluginDefinition): PluginDefinition;
}

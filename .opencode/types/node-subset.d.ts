declare module "fs" {
  export function mkdirSync(path: string, options?: { recursive?: boolean }): string | undefined
  export function symlinkSync(target: string, path: string): void
  export function existsSync(path: string): boolean
  export function readlinkSync(path: string): string
  export function readdirSync(path: string): string[]
  export function readFileSync(path: string, encoding: string): string
  export function rmSync(path: string, options?: { recursive?: boolean }): void
  export function unlinkSync(path: string): void
}

declare module "path" {
  export function join(...paths: string[]): string
  export function dirname(path: string): string
}

declare module "url" {
  export function fileURLToPath(url: string | URL): string
}

declare module "child_process" {
  export function execSync(command: string, options?: { encoding?: string; timeout?: number; stdio?: string[] }): string
}

declare var process: {
  env: Record<string, string | undefined>
}

declare var console: {
  error(...args: unknown[]): void
}

declare module "fs" {
  export function mkdirSync(path: string, options?: { recursive?: boolean }): string | undefined
  export function symlinkSync(target: string, path: string): void
  export function existsSync(path: string): boolean
  export function readlinkSync(path: string): string
}

declare module "path" {
  export function join(...paths: string[]): string
  export function dirname(path: string): string
}

declare module "url" {
  export function fileURLToPath(url: string | URL): string
}

declare var process: {
  env: Record<string, string | undefined>
}

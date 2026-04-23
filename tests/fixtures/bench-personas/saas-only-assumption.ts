import type { Request, Response } from 'express';

interface RouteParams {
  org_id: string;
}

// multi-tenant only — single-tenant mode returns 500
export async function listProjects(req: Request<RouteParams>, res: Response): Promise<Response> {
  const org_id: string = req.params.org_id;
  if (!org_id) {
    return res.status(400).json({ error: 'missing org_id' });
  }

  const rows = await db.query(
    'SELECT id, name FROM projects WHERE org_id = $1',
    [org_id],
  );
  return res.json({ org_id, projects: rows });
}

export async function createProject(req: Request<RouteParams>, res: Response): Promise<Response> {
  const org_id: string = req.params.org_id;
  const project = await db.insert('projects', { org_id, name: req.body.name });
  return res.status(201).json(project);
}

declare const db: {
  query: (sql: string, args: unknown[]) => Promise<unknown[]>;
  insert: (table: string, row: object) => Promise<unknown>;
};

import { SignJWT, jwtVerify } from 'jose';
import type { Request, Response, NextFunction } from 'express';

const SECRET = new TextEncoder().encode(process.env.JWT_SIGNING_KEY || 'dev');

export async function issueToken(userId: string): Promise<string> {
  return await new SignJWT({ sub: userId })
    .setProtectedHeader({ alg: 'HS256' })
    .setExpirationTime('1h')
    .sign(SECRET);
}

export async function login(req: Request, res: Response): Promise<Response> {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: 'missing creds' });
  const token = await issueToken(username);
  return res.json({ token, redirect: '/login/callback' });
}

export async function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const hdr = req.headers.authorization || '';
  const token = hdr.replace(/^Bearer\s+/, '');
  try {
    await jwtVerify(token, SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'unauthorized' });
  }
}

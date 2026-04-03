import jwt, { JwtPayload } from "jsonwebtoken";
import { NextRequest } from "next/server";

export const AUTH_COOKIE = "dhanpath_token";

type AuthTokenPayload = {
  userId: string;
  email: string;
};

function getJwtSecret(): string {
  const secret = process.env.JWT_SECRET;
  if (!secret) {
    throw new Error("Missing JWT_SECRET in environment");
  }
  return secret;
}

export function signAuthToken(payload: AuthTokenPayload): string {
  return jwt.sign(payload, getJwtSecret(), { expiresIn: "7d" });
}

export function verifyAuthToken(token: string): AuthTokenPayload | null {
  try {
    const decoded = jwt.verify(token, getJwtSecret()) as JwtPayload & AuthTokenPayload;
    if (!decoded.userId || !decoded.email) return null;
    return { userId: decoded.userId, email: decoded.email };
  } catch {
    return null;
  }
}

export function readTokenFromRequest(request: NextRequest): string | null {
  const cookieToken = request.cookies.get(AUTH_COOKIE)?.value;
  if (cookieToken) return cookieToken;

  const authHeader = request.headers.get("authorization");
  if (!authHeader) return null;
  const [scheme, token] = authHeader.split(" ");
  if (scheme?.toLowerCase() !== "bearer" || !token) return null;
  return token;
}

export function getAuthUserFromRequest(request: NextRequest): AuthTokenPayload | null {
  const token = readTokenFromRequest(request);
  if (!token) return null;
  return verifyAuthToken(token);
}

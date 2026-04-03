export function toApiErrorMessage(error: unknown): string {
  if (error instanceof Error) {
    const msg = error.message.toLowerCase();

    if (msg.includes("authentication failed") || msg.includes("bad auth")) {
      return "MongoDB authentication failed. Check MONGODB_URI username/password and network access.";
    }

    if (msg.includes("missing mongodb_uri")) {
      return "Missing MONGODB_URI in environment.";
    }

    if (msg.includes("missing jwt_secret")) {
      return "Missing JWT_SECRET in environment.";
    }

    if (msg.includes("timed out") || msg.includes("econnrefused") || msg.includes("enotfound")) {
      return "Unable to reach MongoDB. Verify URI and cluster network access/whitelist.";
    }

    return error.message;
  }

  return "Unexpected server error.";
}

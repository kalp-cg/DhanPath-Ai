import mongoose from "mongoose";

function getMongoUri(): string {
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error("Missing MONGODB_URI in environment");
  }
  return uri;
}

type Cached = {
  conn: typeof mongoose | null;
  promise: Promise<typeof mongoose> | null;
};

declare global {
  var __mongooseCached: Cached | undefined;
}

const cached: Cached = global.__mongooseCached ?? { conn: null, promise: null };

if (!global.__mongooseCached) {
  global.__mongooseCached = cached;
}

export async function connectToMongo(): Promise<typeof mongoose> {
  if (cached.conn) return cached.conn;

  if (!cached.promise) {
    cached.promise = mongoose.connect(getMongoUri(), {
      dbName: process.env.MONGODB_DB ?? "dhanpath",
    });
  }

  cached.conn = await cached.promise;
  return cached.conn;
}

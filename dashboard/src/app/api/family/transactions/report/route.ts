import { NextRequest, NextResponse } from "next/server";

import { getAuthUserFromRequest } from "@/lib/auth";
import { connectToMongo } from "@/lib/mongodb";
import { Family } from "@/models/Family";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";
import { writeAuditLog } from "@/server/audit-log";
import { resolveFamilyAccess } from "@/server/family-access";

function csvCell(value: string | number | null | undefined) {
  const text = String(value ?? "");
  return `"${text.replace(/"/g, '""')}"`;
}

function parseDateParam(value: string | null): Date | null {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

export async function GET(request: NextRequest) {
  const auth = getAuthUserFromRequest(request);
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  await connectToMongo();

  const access = await resolveFamilyAccess(auth.userId);
  if (!access.ok) {
    return NextResponse.json({ error: access.error }, { status: access.status });
  }

  const activeMemberIds = access.members.map((member) => member.userId);

  const user = await User.findById(auth.userId);
  if (!user?.familyId) {
    return NextResponse.json({ error: "no family found for user" }, { status: 404 });
  }

  const family = await Family.findById(user.familyId).lean();
  if (!family) {
    return NextResponse.json({ error: "family not found" }, { status: 404 });
  }

  const memberId = request.nextUrl.searchParams.get("memberId")?.trim() ?? "all";
  const type = request.nextUrl.searchParams.get("type")?.trim() ?? "all";
  const category = request.nextUrl.searchParams.get("category")?.trim() ?? "all";
  const from = parseDateParam(request.nextUrl.searchParams.get("from"));
  const to = parseDateParam(request.nextUrl.searchParams.get("to"));
  const format = request.nextUrl.searchParams.get("format")?.trim().toLowerCase() ?? "csv";

  const query: {
    familyId: unknown;
    userId?: unknown;
    type?: "debit" | "credit";
    category?: string;
    txnTime?: { $gte?: Date; $lte?: Date };
  } = {
    familyId: user.familyId,
    userId: { $in: activeMemberIds },
  };

  if (memberId !== "all") {
    if (!activeMemberIds.includes(memberId)) {
      return NextResponse.json({ error: "member not found in family" }, { status: 404 });
    }
    query.userId = memberId;
  }
  if (type === "debit" || type === "credit") query.type = type;
  if (category !== "all") query.category = category;
  if (from || to) {
    query.txnTime = {};
    if (from) query.txnTime.$gte = from;
    if (to) {
      const inclusiveTo = new Date(to);
      inclusiveTo.setHours(23, 59, 59, 999);
      query.txnTime.$lte = inclusiveTo;
    }
  }

  const txns = await Transaction.find(query).sort({ txnTime: -1 }).limit(5000).lean();
  const userIds = Array.from(new Set(txns.map((txn) => String(txn.userId))));
  const users = await User.find({ _id: { $in: userIds } }).lean();
  const nameMap = new Map(users.map((entry) => [String(entry._id), entry.name ?? "Member"]));

  const rows = txns.map((txn) => ({
    txnTime: new Date(txn.txnTime).toISOString(),
    member: nameMap.get(String(txn.userId)) ?? txn.userEmail,
    type: txn.type,
    amount: Number(txn.amount ?? 0),
    category: txn.category ?? "Uncategorized",
    merchant: txn.merchant ?? "",
    source: txn.source,
  }));

  const filenameDate = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const commonFile = `dhanpath-transactions-report-${filenameDate}`;

  await writeAuditLog({
    familyId: user.familyId,
    actorUserId: user._id,
    action: "transaction_report_exported",
    metadata: {
      format,
      exportedRows: rows.length,
      filters: {
        memberId,
        type,
        category,
        from: from ? from.toISOString().slice(0, 10) : "",
        to: to ? to.toISOString().slice(0, 10) : "",
      },
    },
  });

  if (format === "html") {
    const total = rows.reduce((sum, row) => sum + row.amount * (row.type === "credit" ? -1 : 1), 0);
    const html = `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>DhanPath Transactions Report</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 24px; color: #1f2937; }
      h1 { margin-bottom: 4px; }
      p { margin: 2px 0; }
      table { width: 100%; border-collapse: collapse; margin-top: 16px; }
      th, td { border: 1px solid #d1d5db; padding: 8px; font-size: 12px; text-align: left; }
      th { background: #f3f4f6; }
      .meta { margin-top: 10px; }
      .total { margin-top: 12px; font-weight: 700; }
      @media print { .no-print { display: none; } }
    </style>
  </head>
  <body>
    <h1>${family.name} - Transactions Report</h1>
    <p>Prepared for CA sharing</p>
    <p class="meta">Generated on: ${new Date().toLocaleString()}</p>
    <p class="meta">Filters: member=${memberId}, type=${type}, category=${category}, from=${from ? from.toISOString().slice(0, 10) : "all"}, to=${to ? to.toISOString().slice(0, 10) : "all"}</p>
    <button class="no-print" onclick="window.print()">Print / Save as PDF</button>
    <table>
      <thead>
        <tr>
          <th>Date</th><th>Member</th><th>Type</th><th>Amount</th><th>Category</th><th>Merchant</th><th>Source</th>
        </tr>
      </thead>
      <tbody>
        ${rows
          .map(
            (row) => `<tr><td>${row.txnTime}</td><td>${row.member}</td><td>${row.type}</td><td>${row.amount.toFixed(2)}</td><td>${row.category}</td><td>${row.merchant}</td><td>${row.source}</td></tr>`,
          )
          .join("")}
      </tbody>
    </table>
    <p class="total">Net Spend (debit-credit): INR ${total.toFixed(2)}</p>
  </body>
</html>`;

    return new NextResponse(html, {
      status: 200,
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  }

  const header = ["date", "member", "type", "amount", "category", "merchant", "source"];
  const csv = [header, ...rows.map((row) => [row.txnTime, row.member, row.type, row.amount, row.category, row.merchant, row.source])]
    .map((line) => line.map((cell) => csvCell(cell)).join(","))
    .join("\n");

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename=\"${commonFile}.csv\"`,
      "Cache-Control": "no-store",
    },
  });
}

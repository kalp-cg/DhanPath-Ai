import { randomBytes } from "crypto";

import { Types } from "mongoose";

import { AuditLog } from "@/models/AuditLog";
import { CaPackShareToken } from "@/models/CaPackShareToken";
import { Family } from "@/models/Family";
import { Transaction } from "@/models/Transaction";
import { User } from "@/models/User";

export type CaPackData = {
  familyName: string;
  periodLabel: string;
  filters: { year: number; month: number };
  rows: Array<{
    date: string;
    member: string;
    type: "debit" | "credit";
    amount: number;
    category: string;
    merchant: string;
    source: string;
  }>;
  auditRows: Array<{
    at: string;
    action: string;
    actor: string;
    target: string;
  }>;
  totals: {
    debit: number;
    credit: number;
    net: number;
  };
};

export function getMonthBounds(year: number, month: number) {
  const start = new Date(year, month - 1, 1);
  const end = new Date(year, month, 1);
  return { start, end };
}

export async function buildCaPackData(params: {
  familyId: Types.ObjectId;
  year: number;
  month: number;
  includeAudit: boolean;
}): Promise<CaPackData | null> {
  const family = await Family.findById(params.familyId).lean();
  if (!family) return null;

  const { start, end } = getMonthBounds(params.year, params.month);
  const txns = await Transaction.find({
    familyId: params.familyId,
    txnTime: { $gte: start, $lt: end },
  })
    .sort({ txnTime: -1 })
    .limit(10000)
    .lean();

  const memberIds = Array.from(new Set(txns.map((txn) => String(txn.userId))));
  const users = await User.find({ _id: { $in: memberIds } }).lean();
  const nameMap = new Map(users.map((user) => [String(user._id), user.name ?? "Member"]));

  const rows = txns.map((txn) => ({
    date: new Date(txn.txnTime).toISOString(),
    member: nameMap.get(String(txn.userId)) ?? txn.userEmail,
    type: txn.type,
    amount: Number(txn.amount ?? 0),
    category: txn.category ?? "Uncategorized",
    merchant: txn.merchant ?? "",
    source: txn.source,
  }));

  const debit = rows.filter((row) => row.type === "debit").reduce((sum, row) => sum + row.amount, 0);
  const credit = rows.filter((row) => row.type === "credit").reduce((sum, row) => sum + row.amount, 0);

  let auditRows: CaPackData["auditRows"] = [];
  if (params.includeAudit) {
    const audits = await AuditLog.find({
      familyId: params.familyId,
      createdAt: { $gte: start, $lt: end },
    })
      .sort({ createdAt: -1 })
      .limit(2000)
      .lean();

    const auditUserIds = Array.from(
      new Set(
        audits
          .flatMap((audit) => [String(audit.actorUserId), audit.targetUserId ? String(audit.targetUserId) : ""])
          .filter(Boolean),
      ),
    );
    const auditUsers = await User.find({ _id: { $in: auditUserIds } }).lean();
    const auditNameMap = new Map(auditUsers.map((user) => [String(user._id), user.name ?? "Member"]));

    auditRows = audits.map((audit) => ({
      at: new Date(audit.createdAt).toISOString(),
      action: String(audit.action),
      actor: auditNameMap.get(String(audit.actorUserId)) ?? "Unknown",
      target: audit.targetUserId ? auditNameMap.get(String(audit.targetUserId)) ?? "Member" : "",
    }));
  }

  return {
    familyName: family.name,
    periodLabel: `${params.year}-${String(params.month).padStart(2, "0")}`,
    filters: { year: params.year, month: params.month },
    rows,
    auditRows,
    totals: {
      debit,
      credit,
      net: debit - credit,
    },
  };
}

export async function createCaPackToken(params: {
  familyId: Types.ObjectId;
  createdByUserId: Types.ObjectId;
  year: number;
  month: number;
  includeAudit: boolean;
  expiresDays: number;
}) {
  const token = randomBytes(24).toString("hex");
  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + Math.max(1, Math.min(30, params.expiresDays)));

  await CaPackShareToken.create({
    familyId: params.familyId,
    createdByUserId: params.createdByUserId,
    token,
    year: params.year,
    month: params.month,
    includeAudit: params.includeAudit,
    expiresAt,
  });

  return { token, expiresAt };
}

export function buildCaPackCsv(data: CaPackData) {
  const esc = (value: string | number) => `"${String(value).replace(/"/g, '""')}"`;
  const header = ["date", "member", "type", "amount", "category", "merchant", "source"];
  const rows = data.rows.map((row) => [row.date, row.member, row.type, row.amount, row.category, row.merchant, row.source]);
  return [header, ...rows].map((line) => line.map((cell) => esc(cell)).join(",")).join("\n");
}

export function buildCaPackHtml(data: CaPackData) {
  return `<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>DhanPath CA Pack</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 24px; color: #1f2937; }
      h1 { margin-bottom: 2px; }
      p { margin: 2px 0; }
      table { width: 100%; border-collapse: collapse; margin-top: 14px; }
      th, td { border: 1px solid #d1d5db; padding: 8px; font-size: 12px; text-align: left; }
      th { background: #f3f4f6; }
      .meta { margin: 6px 0; }
      .section { margin-top: 24px; }
      .total { margin-top: 10px; font-weight: 700; }
      @media print { .no-print { display: none; } }
    </style>
  </head>
  <body>
    <h1>${data.familyName} - CA Pack</h1>
    <p>Period: ${data.periodLabel}</p>
    <p class="meta">Generated on: ${new Date().toLocaleString()}</p>
    <button class="no-print" onclick="window.print()">Print / Save as PDF</button>

    <div class="section">
      <h2>Transactions</h2>
      <table>
        <thead>
          <tr><th>Date</th><th>Member</th><th>Type</th><th>Amount</th><th>Category</th><th>Merchant</th><th>Source</th></tr>
        </thead>
        <tbody>
          ${data.rows
            .map(
              (row) => `<tr><td>${row.date}</td><td>${row.member}</td><td>${row.type}</td><td>${row.amount.toFixed(2)}</td><td>${row.category}</td><td>${row.merchant}</td><td>${row.source}</td></tr>`,
            )
            .join("")}
        </tbody>
      </table>
      <p class="total">Debit: INR ${data.totals.debit.toFixed(2)} | Credit: INR ${data.totals.credit.toFixed(2)} | Net: INR ${data.totals.net.toFixed(2)}</p>
    </div>

    ${data.auditRows.length > 0 ? `
      <div class="section">
        <h2>Audit Activity</h2>
        <table>
          <thead><tr><th>At</th><th>Action</th><th>Actor</th><th>Target</th></tr></thead>
          <tbody>
            ${data.auditRows
              .map(
                (row) => `<tr><td>${row.at}</td><td>${row.action}</td><td>${row.actor}</td><td>${row.target}</td></tr>`,
              )
              .join("")}
          </tbody>
        </table>
      </div>
    ` : ""}
  </body>
</html>`;
}

import Link from "next/link";
import { notFound } from "next/navigation";

import { connectToMongo } from "@/lib/mongodb";
import { CaPackShareToken } from "@/models/CaPackShareToken";
import { buildCaPackData } from "@/server/ca-pack";

export default async function CaPackTokenPage({ params }: { params: Promise<{ token: string }> }) {
  const { token } = await params;
  if (!token) notFound();

  await connectToMongo();

  const share = await CaPackShareToken.findOne({ token }).lean();
  if (!share) notFound();
  const now = new Date();
  if (new Date(share.expiresAt).getTime() < now.getTime()) {
    return (
      <main style={{ padding: 24, fontFamily: "Arial, sans-serif" }}>
        <h1>CA Pack Link Expired</h1>
        <p>This sharing token has expired. Ask the family admin to generate a new CA pack link.</p>
      </main>
    );
  }

  const data = await buildCaPackData({
    familyId: share.familyId,
    year: share.year,
    month: share.month,
    includeAudit: share.includeAudit,
  });
  if (!data) notFound();

  const csvHref = `/api/family/ca-pack/${token}/csv`;
  const pdfHref = `/api/family/ca-pack/${token}/pdf`;

  return (
    <main style={{ padding: 24, fontFamily: "Arial, sans-serif", color: "#1f2937" }}>
      <h1>{data.familyName} - CA Pack</h1>
      <p>Period: {data.periodLabel}</p>
      <p>Rows: {data.rows.length} transactions</p>
      <p>
        Debit: INR {data.totals.debit.toFixed(2)} | Credit: INR {data.totals.credit.toFixed(2)} | Net: INR {data.totals.net.toFixed(2)}
      </p>
      <p>Expires: {new Date(share.expiresAt).toLocaleString()}</p>

      <div style={{ display: "flex", gap: 10, marginTop: 12, flexWrap: "wrap" }}>
        <Link href={csvHref}>Download CSV</Link>
        <Link href={pdfHref} target="_blank">Open PDF View</Link>
      </div>

      <h2 style={{ marginTop: 22 }}>Recent Transactions</h2>
      <table style={{ width: "100%", borderCollapse: "collapse", marginTop: 10 }}>
        <thead>
          <tr>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Date</th>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Member</th>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Type</th>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Amount</th>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Category</th>
            <th style={{ border: "1px solid #d1d5db", padding: 8, textAlign: "left" }}>Merchant</th>
          </tr>
        </thead>
        <tbody>
          {data.rows.slice(0, 200).map((row) => (
            <tr key={`${row.date}-${row.member}-${row.amount}`}>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.date}</td>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.member}</td>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.type}</td>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.amount.toFixed(2)}</td>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.category}</td>
              <td style={{ border: "1px solid #d1d5db", padding: 8 }}>{row.merchant}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </main>
  );
}

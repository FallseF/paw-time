import { ApplicationList } from "../../features/applicants/ApplicationList";
import { listApplications } from "../../lib/api";

export const dynamic = "force-dynamic";

export default async function ApplicationsPage() {
  const applications = await listApplications();
  return <><header className="pageHeader"><div><p className="eyebrow">APPLICATIONS</p><h1>応募者</h1><p>応募内容を確認し、採用結果を記録します。</p></div></header><ApplicationList applications={applications} /></>;
}

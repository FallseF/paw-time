import { JobList } from "../../features/job-postings/JobList";
import { listJobs } from "../../lib/api";

export const dynamic = "force-dynamic";

export default async function JobsPage() {
  const jobs = await listJobs();
  return <><header className="pageHeader"><div><p className="eyebrow">RECRUITMENT</p><h1>求人</h1><p>下書きから公開終了までを管理します。</p></div><button className="primaryButton">新しい求人</button></header><JobList jobs={jobs} /></>;
}

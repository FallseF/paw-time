import type { JobPosting } from "@paw-time/api-contracts";
import { EmptyState } from "../../components/EmptyState";

const statusLabel: Record<JobPosting["status"], string> = {
  draft: "下書き",
  published: "公開中",
  closed: "終了",
};

export function JobList({ jobs }: { jobs: JobPosting[] | null }) {
  if (!jobs) {
    return <EmptyState title="APIに接続できません" description="先にAPIを起動してください。" />;
  }
  if (jobs.length === 0) {
    return <EmptyState title="求人はまだありません" description="最初の求人を作成しましょう。" />;
  }
  return (
    <div className="tableCard">
      <table>
        <thead>
          <tr>
            <th>求人</th>
            <th>開始</th>
            <th>募集</th>
            <th>時給</th>
            <th>状態</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((job) => (
            <tr key={job.id}>
              <td>
                <strong>{job.title}</strong>
                <span>{job.role}</span>
              </td>
              <td>{new Date(job.startsAt).toLocaleString("ja-JP")}</td>
              <td>{job.capacity}人</td>
              <td>¥{job.hourlyWage.toLocaleString("ja-JP")}</td>
              <td><span className={`status status-${job.status}`}>{statusLabel[job.status]}</span></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
